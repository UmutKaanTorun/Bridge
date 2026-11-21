import Foundation
import Testing
@testable import KopruCore

struct EngineTests {
    /// İçinde çalıştırılabilir bin/wine olan sahte motor klasörü.
    private func makeEngine(_ td: TempDir, _ name: String) throws -> URL {
        let wine = try td.file("\(name)/bin/wine", "#!/bin/sh\n")
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)
        return td.url.appendingPathComponent(name, isDirectory: true)
    }

    @Test func prefersEngineInsideTheApp() throws {
        let td = try TempDir()
        _ = try makeEngine(td, "Resources/Motor")
        let env = try makeEngine(td, "env")
        let dev = try makeEngine(td, "dev")
        let engine = try Engine.locate(bundleResources: td.url.appendingPathComponent("Resources"),
                                       environment: ["KOPRU_MOTOR": env.path],
                                       developmentFallback: dev)
        #expect(engine.root.lastPathComponent == "Motor")
    }

    @Test func fallsBackToEnvironmentThenDevelopment() throws {
        let td = try TempDir()
        let env = try makeEngine(td, "env")
        let dev = try makeEngine(td, "dev")
        let missingResources = td.url.appendingPathComponent("Resources")
        #expect(try Engine.locate(bundleResources: missingResources, environment: ["KOPRU_MOTOR": env.path],
                                  developmentFallback: dev).root.path == env.path)
        #expect(try Engine.locate(bundleResources: missingResources, environment: [:],
                                  developmentFallback: dev).root.path == dev.path)
    }

    @Test func reportsSearchedPlacesWhenMissing() throws {
        let td = try TempDir()
        #expect(throws: EngineError.notFound(searched: [td.url.appendingPathComponent("Resources/Motor").path])) {
            try Engine.locate(bundleResources: td.url.appendingPathComponent("Resources"), environment: [:], developmentFallback: nil)
        }
    }

    @Test func rosettaCheck() throws {
        #expect(throws: EngineError.rosettaMissing) { try Engine.checkRosetta(fileExists: { _ in false }) }
        try Engine.checkRosetta(fileExists: { $0 == Engine.rosettaRuntimePath })
    }

    @Test func buildsWineEnvironment() {
        let engine = Engine(root: URL(fileURLWithPath: "/Motor", isDirectory: true))
        let prefix = URL(fileURLWithPath: "/Bottles/Steam", isDirectory: true)
        let env = engine.environment(prefix: prefix,
                                     settings: BottleSettings(msync: true, virtualDesktop: .off, fpsHud: false),
                                     base: ["PATH": "/usr/bin:/bin", "MTL_HUD_ENABLED": "1"])
        #expect(env["PATH"] == "/usr/bin:/bin")
        #expect(env["WINEPREFIX"] == "/Bottles/Steam")
        #expect(env["DYLD_FALLBACK_LIBRARY_PATH"] == "/Motor/lib")
        #expect(env["WINEMSYNC"] == "1")
        #expect(env["MVK_CONFIG_LOG_LEVEL"] == "0")
        #expect(env["WINEDEBUG"] == "-all")
        #expect(env["MTL_HUD_ENABLED"] == nil)
        #expect(engine.wine.path == "/Motor/bin/wine")
        #expect(engine.wineserver.path == "/Motor/bin/wineserver")
    }

    @Test func environmentFollowsSettingsAndKeepsWineDebug() {
        let engine = Engine(root: URL(fileURLWithPath: "/Motor", isDirectory: true))
        let env = engine.environment(prefix: URL(fileURLWithPath: "/B"),
                                     settings: BottleSettings(msync: false, virtualDesktop: .off, fpsHud: true),
                                     base: ["WINEDEBUG": "+loaddll"])
        #expect(env["WINEMSYNC"] == "0")
        #expect(env["MTL_HUD_ENABLED"] == "1")
        #expect(env["WINEDEBUG"] == "+loaddll")
    }

    @Test func wined3dProgramsBecomeEngineVariable() {
        let engine = Engine(root: URL(fileURLWithPath: "/Motor", isDirectory: true))
        let settings = BottleSettings(wined3dPrograms: ["Launcher.exe", " LauncherPatcher.exe ", "", "a,b.exe"])
        let env = engine.environment(prefix: URL(fileURLWithPath: "/B"), settings: settings, base: [:])
        // Virgül motorda ayırıcı; virgüllü ya da boş adlar atlanır.
        #expect(env[Engine.wined3dProgramsVariable] == "Launcher.exe,LauncherPatcher.exe")
    }

    @Test func noWined3dProgramsClearsEngineVariable() {
        let engine = Engine(root: URL(fileURLWithPath: "/Motor", isDirectory: true))
        let base = [Engine.wined3dProgramsVariable: "Launcher.exe"]
        for settings in [BottleSettings(), BottleSettings(wined3dPrograms: []), BottleSettings(wined3dPrograms: [" "])] {
            let env = engine.environment(prefix: URL(fileURLWithPath: "/B"), settings: settings, base: base)
            #expect(env[Engine.wined3dProgramsVariable] == nil)
        }
    }
}
