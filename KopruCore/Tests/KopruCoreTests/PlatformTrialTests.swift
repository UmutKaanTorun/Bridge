import CoreGraphics
import Foundation
import Testing
@testable import KopruCore

/// Platform tariflerini gerçek motor ve gerçek ağla dener: hepsini aynı anda kurar, sonra her birini sırayla
/// açıp pencerelerinin ekran görüntüsünü alır. Bottle'lar silinmez; sonuçlar `<kök>/sonuc` klasörüne yazılır.
///
///     KOPRU_TARIF_DENE=epic,gog-galaxy KOPRU_TARIF_DENE_KOK=~/WineBottles/kopru-platform swift test --filter PlatformTrialTests
///
/// `KOPRU_TARIF_DENE_KUR=0` kurulumu atlar (bottle'lar önceki denemeden kalmış olmalı).
@Suite(.enabled(if: ProcessInfo.processInfo.environment["KOPRU_TARIF_DENE"] != nil), .serialized)
struct PlatformTrialTests {
    static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    @Test(.timeLimit(.minutes(60)))
    func installAndOpenPlatforms() async throws {
        let env = ProcessInfo.processInfo.environment
        let ids = (env["KOPRU_TARIF_DENE"] ?? "").split(separator: ",").map(String.init)
        let root = URL(fileURLWithPath: NSString(string: env["KOPRU_TARIF_DENE_KOK"] ?? "~/WineBottles/kopru-platform").expandingTildeInPath)
        let installMinutes = Int(env["KOPRU_TARIF_DENE_DK"] ?? "") ?? 15
        let openSeconds = Int(env["KOPRU_TARIF_DENE_SN"] ?? "") ?? 90
        let results = root.appendingPathComponent("sonuc", isDirectory: true)
        try FileManager.default.createDirectory(at: results, withIntermediateDirectories: true)
        let paths = KopruPaths(applicationSupport: root.appendingPathComponent("AppSupport", isDirectory: true),
                               logs: root.appendingPathComponent("Logs", isDirectory: true))
        let engine = try Engine.locate(bundleResources: nil, environment: env, developmentFallback: Engine.developmentEngine)
        let runner = WineRunner(engine: engine, paths: paths)
        let catalog = try RecipeCatalog.load(recipesDirectory: Self.repo.appendingPathComponent("Resources/Recipes"),
                                             filesDirectory: Self.repo.appendingPathComponent("Resources/RecipeFiles"))
        let store = BottleStore(paths: paths)
        let recipes = try ids.map { id in try #require(catalog.recipe(id: id), "Tarif yok: \(id)") }
        let journal = Journal(directory: results)

        if env["KOPRU_TARIF_DENE_KUR"] != "0" {
            await withTaskGroup(of: Void.self) { group in
                for recipe in recipes {
                    group.addTask {
                        await Self.install(recipe, runner: runner, catalog: catalog, store: store, paths: paths,
                                           minutes: installMinutes, journal: journal)
                    }
                }
            }
        }

        for recipe in recipes {
            guard let bottle = try store.list().first(where: { $0.info.recipeId == recipe.id }) else {
                journal.write(recipe.id, "açılış atlandı: bottle yok")
                continue
            }
            await Self.open(recipe, bottle: bottle, runner: runner, catalog: catalog, seconds: openSeconds,
                            results: results, journal: journal)
        }
    }

    private static func install(_ recipe: Recipe, runner: WineRunner, catalog: RecipeCatalog, store: BottleStore,
                                paths: KopruPaths, minutes: Int, journal: Journal) async {
        let start = Date()
        let installer = RecipeInstaller(factory: BottleFactory(store: store, runner: runner), runner: runner,
                                        actions: RecipeActionPerformer(runner: runner, catalog: catalog),
                                        downloader: Downloader(), downloadsDirectory: paths.downloads)
        let created = BottleBox()
        let work = Task {
            try await installer.install(recipe, bottleName: recipe.bottle.defaultName) { event in
                switch event {
                case .progress: break
                case let .bottleCreated(bottle): created.set(bottle)
                default: journal.write(recipe.id, "\(event) +\(Int(Date().timeIntervalSince(start))) sn")
                }
            }
        }
        let watchdog = Task {
            // Kurulum takılırsa (kurucu programı açıp beklerse) her 30 sn'de detect durumunu yaz, süre dolunca öldür.
            let deadline = Date().addingTimeInterval(TimeInterval(minutes * 60))
            while Date() < deadline {
                try await Task.sleep(for: .seconds(30))
                if let bottle = created.value {
                    journal.write(recipe.id, "… +\(Int(Date().timeIntervalSince(start))) sn, detect: \(recipe.isInstalled(in: bottle.url))")
                }
            }
            journal.write(recipe.id, "SÜRE DOLDU (\(minutes) dk): wineserver öldürülüyor")
            if let bottle = created.value { await runner.killWineserver(prefix: bottle.url, settings: bottle.info.settings) }
        }
        do {
            let bottle = try await work.value
            watchdog.cancel()
            journal.write(recipe.id, "KURULDU \(Int(Date().timeIntervalSince(start))) sn, detect: \(recipe.isInstalled(in: bottle.url))")
            await runner.waitForWineserver(prefix: bottle.url, settings: bottle.info.settings, timeout: .seconds(60))
            journal.write(recipe.id, "wineserver bitti/zaman aşımı; yeniden detect: \(recipe.isInstalled(in: bottle.url))")
        } catch {
            watchdog.cancel()
            let step = (error as? InstallFailure)?.step.rawValue ?? "?"
            journal.write(recipe.id, "KURULAMADI adım=\(step): \(error.localizedDescription) (\(Int(Date().timeIntervalSince(start))) sn)")
            if let bottle = created.value {
                journal.write(recipe.id, "detect: \(recipe.isInstalled(in: bottle.url))")
                await runner.killWineserver(prefix: bottle.url, settings: bottle.info.settings)
            }
        }
    }

    private static func open(_ recipe: Recipe, bottle: Bottle, runner: WineRunner, catalog: RecipeCatalog, seconds: Int,
                             results: URL, journal: Journal) async {
        let actions = RecipeActionPerformer(runner: runner, catalog: catalog)
        do {
            try await actions.perform(recipe.beforeLaunch, recipe: recipe, bottle: bottle)
        } catch {
            journal.write(recipe.id, "beforeLaunch hatası: \(error.localizedDescription)")
        }
        let target = LaunchTarget.windowsPath(recipe.launch.windowsPath, arguments: recipe.launch.arguments(forBottleAt: bottle.url))
        let start = Date()
        let clockStart = ContinuousClock.now
        // AppModel.start ile aynı: whileRunning eylemleri Wine çalıştığı sürece yeniden uygulanır.
        let guardTask = Task {
            await actions.keepApplying(recipe.whileRunning ?? [], recipe: recipe, bottle: bottle, while: {
                runner.isRunning(bottle) || WineServerStatus.isRunning(prefix: bottle.url)
            })
        }
        defer { guardTask.cancel() }
        let launch = Task { try await runner.run(target, in: bottle, appName: recipe.launch.name) }
        journal.write(recipe.id, "AÇILIYOR \(target)")
        var shot = 0
        var ended = false
        for second in stride(from: 15, through: seconds, by: 15) {
            try? await Task.sleep(until: clockStart + .seconds(second))
            let windows = Self.windows(owner: recipe.launch.name)
            let alive = runner.isRunning(bottle) || WineServerStatus.isRunning(prefix: bottle.url)
            journal.write(recipe.id, "+\(second) sn: wine canlı=\(alive), pencereler=\(windows.map { "\($0.title)[\($0.width)x\($0.height)]" })")
            if let biggest = windows.max(by: { $0.width * $0.height < $1.width * $1.height }) {
                shot += 1
                let file = results.appendingPathComponent("\(recipe.id)-\(shot).png")
                let capture = Process()
                capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-o", "-l", String(biggest.id), file.path]
                try? capture.run()
                capture.waitUntilExit()
            }
            if !alive { ended = true; break }
        }
        if !ended {
            await runner.stop(bottle, shutdown: nil, grace: .seconds(3))
        }
        if let result = try? await launch.value {
            journal.write(recipe.id, "çıkış kodu \(result.exitCode), \(Int(result.duration)) sn")
        }
    }

    struct WindowInfo { let id: UInt32; let title: String; let width: Int; let height: Int }

    /// Sahibi `owner` adlı süreç olan ekrandaki pencereler (Köprü'nün Dock adı yaması süreç adını değiştirir).
    static func windows(owner: String) -> [WindowInfo] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { info in
            guard (info[kCGWindowOwnerName as String] as? String) == owner,
                  let id = info[kCGWindowNumber as String] as? UInt32,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any] else { return nil }
            let width = (bounds["Width"] as? NSNumber)?.intValue ?? 0
            let height = (bounds["Height"] as? NSNumber)?.intValue ?? 0
            guard width > 40, height > 40 else { return nil }
            return WindowInfo(id: id, title: info[kCGWindowName as String] as? String ?? "", width: width, height: height)
        }
    }
}

/// Sonuç günlüğü: konsola ve `<id>.txt` dosyasına.
private final class Journal: @unchecked Sendable {
    let directory: URL
    private let lock = NSLock()

    init(directory: URL) { self.directory = directory }

    func write(_ id: String, _ line: String) {
        let text = "\(Date().formatted(date: .omitted, time: .standard)) [\(id)] \(line)\n"
        lock.withLock {
            print(text, terminator: "")
            let url = directory.appendingPathComponent("\(id).txt")
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(text.utf8))
                try? handle.close()
            } else {
                try? Data(text.utf8).write(to: url)
            }
        }
    }
}

private final class BottleBox: @unchecked Sendable {
    private let lock = NSLock()
    private var bottle: Bottle?

    func set(_ value: Bottle) { lock.withLock { bottle = value } }
    var value: Bottle? { lock.withLock { bottle } }
}
