import Foundation

public struct RunResult: Equatable, Sendable {
    public let exitCode: Int32
    public let duration: TimeInterval
}

/// Wine süreçlerini başlatır, çıktıyı bottle'ın günlüğüne yazar, bottle'ı durdurur.
public final class WineRunner: @unchecked Sendable {
    public let engine: Engine
    public let paths: KopruPaths
    private let baseEnvironment: [String: String]
    private let lock = NSLock()
    private var counts: [String: Int] = [:]

    public init(engine: Engine, paths: KopruPaths, baseEnvironment: [String: String] = ProcessInfo.processInfo.environment) {
        self.engine = engine
        self.paths = paths
        self.baseEnvironment = baseEnvironment
    }

    /// Köprü'nün bu bottle'da başlattığı ve henüz bitmemiş süreç var mı.
    public func isRunning(_ bottle: Bottle) -> Bool {
        lock.withLock { (counts[bottle.folderName] ?? 0) > 0 }
    }

    /// Programı başlatır ve bitmesini bekler. Görev iptal edilirse süreç sonlandırılır (SIGTERM);
    /// programın açtığı öteki Windows süreçleri için ayrıca `killWineserver` gerekir.
    /// `appName`: Dock'ta "wine" yerine görünecek ad; programın açtığı alt süreçler de devralır.
    public func run(_ target: LaunchTarget, in bottle: Bottle,
                    appName: String? = nil, extraEnvironment: [String: String] = [:]) async throws -> RunResult {
        let arguments = WineArguments.arguments(for: target)

        let process = Process()
        process.executableURL = engine.wine
        process.arguments = arguments
        var environment = engine.environment(prefix: bottle.url, settings: bottle.info.settings, base: baseEnvironment)
        environment[Engine.appNameVariable] = appName
        process.environment = environment.merging(extraEnvironment) { _, new in new }
        if case let .unixFile(file, _) = target {
            process.currentDirectoryURL = file.deletingLastPathComponent()
        } else {
            process.currentDirectoryURL = bottle.url
        }

        let log = try openLog(for: bottle)
        log.write(Data("\n=== \(Date().formatted(.iso8601)) wine \(arguments.joined(separator: " "))\n".utf8))
        process.standardOutput = log
        process.standardError = log

        let key = bottle.folderName
        let start = Date()
        adjust(key, by: 1)
        let box = ProcessBox(process)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { [self] finished in
                    adjust(key, by: -1)
                    try? log.close()
                    continuation.resume(returning: RunResult(exitCode: finished.terminationStatus,
                                                             duration: Date().timeIntervalSince(start)))
                }
                do {
                    try process.run()
                    // İptal süreç başlamadan geldiyse işleyici sonlandıracak süreç bulamamıştır.
                    if Task.isCancelled { box.terminateIfRunning() }
                } catch {
                    adjust(key, by: -1)
                    try? log.close()
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            box.terminateIfRunning()
        }
    }

    /// `wineserver -k`: bottle'daki bütün Windows süreçlerini kapatır.
    public func killWineserver(prefix: URL, settings: BottleSettings) async {
        await runWineserver(["-k"], prefix: prefix, settings: settings, timeout: nil)
    }

    /// `wineserver -w`: bottle'daki süreçler bitip wineserver kapanana kadar bekler.
    /// Wine kayıt defterini (system.reg, user.reg) diske ancak o zaman yazar.
    /// Takılan bir süreç Köprü'yü kilitlemesin diye `timeout` sonunda beklemeyi bırakır.
    public func waitForWineserver(prefix: URL, settings: BottleSettings, timeout: Duration = .seconds(30)) async {
        await runWineserver(["-w"], prefix: prefix, settings: settings, timeout: timeout)
    }

    private func runWineserver(_ arguments: [String], prefix: URL, settings: BottleSettings, timeout: Duration?) async {
        let process = Process()
        process.executableURL = engine.wineserver
        process.arguments = arguments
        process.environment = engine.environment(prefix: prefix, settings: settings, base: baseEnvironment)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let box = ProcessBox(process)
        let timer = timeout.map { limit in
            Task {
                try? await Task.sleep(for: limit)
                box.terminateIfRunning()
            }
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
            do { try process.run() } catch { continuation.resume() }
        }
        timer?.cancel()
    }

    /// Önce programı kibarca kapatmayı dener (`shutdown`), `grace` kadar bekler, sonra wineserver'ı öldürür.
    public func stop(_ bottle: Bottle, shutdown: LaunchTarget? = nil, grace: Duration = .seconds(10)) async {
        if let shutdown {
            Task { _ = try? await self.run(shutdown, in: bottle) }
            let clock = ContinuousClock()
            let deadline = clock.now + grace
            try? await Task.sleep(for: .milliseconds(300))
            while clock.now < deadline && isRunning(bottle) {
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
        await killWineserver(prefix: bottle.url, settings: bottle.info.settings)
    }

    func openLog(for bottle: Bottle) throws -> FileHandle {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.logs, withIntermediateDirectories: true)
        let url = paths.logFile(forBottleFolder: bottle.folderName)
        if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        return handle
    }

    private func adjust(_ key: String, by delta: Int) {
        lock.withLock { counts[key, default: 0] += delta }
    }
}

/// Zaman aşımı görevinin süreci sonlandırabilmesi için.
private final class ProcessBox: @unchecked Sendable {
    private let process: Process

    init(_ process: Process) { self.process = process }

    func terminateIfRunning() {
        if process.isRunning { process.terminate() }
    }
}
