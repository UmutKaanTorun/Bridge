import Foundation
import Testing
@testable import KopruCore

struct WineRunnerTests {
    private func setUp(_ td: TempDir, _ extra: [String: String] = [:]) throws -> (WineRunner, Bottle) {
        let runner = WineRunner(engine: try td.fakeEngine(), paths: td.paths, baseEnvironment: td.environment(extra))
        let bottle = try BottleStore(paths: td.paths).makeBottle(name: "Deneme", settings: .default, recipeId: nil)
        return (runner, bottle)
    }

    @Test func passesArgumentsAndEnvironment() async throws {
        let td = try TempDir()
        let (runner, bottle) = try setUp(td, ["CIKIS": "3"])
        let result = try await runner.run(.windowsPath("C:\\x.exe", arguments: ["-a"]), in: bottle)
        #expect(result.exitCode == 3)
        let lines = td.recordedLines()
        #expect(lines.first == "wine C:\\x.exe -a")
        #expect(lines.dropFirst().first?.hasPrefix("WINEPREFIX=\(bottle.url.path) WINEMSYNC=1 PWD=") == true)
        #expect(lines.dropFirst().first?.hasSuffix("/Deneme") == true)
    }

    @Test func writesOutputToBottleLog() async throws {
        let td = try TempDir()
        let (runner, bottle) = try setUp(td)
        _ = try await runner.run(.builtin("winecfg", arguments: []), in: bottle)
        _ = try await runner.run(.builtin("cmd", arguments: ["/c", "ver"]), in: bottle)
        let log = try String(contentsOf: td.paths.logFile(forBottleFolder: "Deneme"), encoding: .utf8)
        #expect(log.contains("=== "))
        #expect(log.contains("wine winecfg"))
        #expect(log.contains("wine cmd /c ver"))
        #expect(log.components(separatedBy: "sahte cikti").count == 3)
    }

    @Test func unixFileRunsInItsFolder() async throws {
        let td = try TempDir()
        let (runner, bottle) = try setUp(td)
        let setup = try td.file("Indirilenler/setup.exe")
        _ = try await runner.run(.unixFile(setup, arguments: ["/S"]), in: bottle)
        #expect(td.recordedLines().dropFirst().first?.hasSuffix("/Indirilenler") == true)
    }

    @Test func extraEnvironmentAndDesktop() async throws {
        let td = try TempDir()
        let (runner, bottle) = try setUp(td)
        _ = try await runner.run(.windowsPath("C:\\a.exe", arguments: []), in: bottle,
                                 desktopSize: PixelSize(width: 800, height: 600), extraEnvironment: ["WINEMSYNC": "0"])
        let lines = td.recordedLines()
        #expect(lines.first == "wine explorer /desktop=Kopru-Deneme,800x600 C:\\a.exe")
        #expect(lines.dropFirst().first?.contains("WINEMSYNC=0") == true)
    }

    @Test func tracksRunningProcesses() async throws {
        let td = try TempDir()
        let (runner, bottle) = try setUp(td, ["UYKU": "1"])
        #expect(!runner.isRunning(bottle))
        let task = Task { try await runner.run(.windowsPath("C:\\a.exe", arguments: []), in: bottle) }
        try await Task.sleep(for: .milliseconds(300))
        #expect(runner.isRunning(bottle))
        _ = try await task.value
        #expect(!runner.isRunning(bottle))
    }

    @Test func stopRunsShutdownThenKillsWineserver() async throws {
        let td = try TempDir()
        let (runner, bottle) = try setUp(td)
        await runner.stop(bottle, shutdown: .windowsPath("C:\\Steam\\steam.exe", arguments: ["-shutdown"]), grace: .seconds(2))
        let commands = td.recordedLines().filter { !$0.hasPrefix("WINEPREFIX=") }
        #expect(commands == ["wine C:\\Steam\\steam.exe -shutdown", "wineserver -k"])
    }

    @Test func stopWithoutShutdownOnlyKills() async throws {
        let td = try TempDir()
        let (runner, bottle) = try setUp(td)
        await runner.stop(bottle)
        #expect(td.recordedLines().filter { !$0.hasPrefix("WINEPREFIX=") } == ["wineserver -k"])
    }
}
