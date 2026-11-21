import Foundation
import Testing
@testable import KopruCore

/// Gerçek CrossOver 26.3.0 + DXMT motoruyla; yavaş (~1 dk). Çalıştırmak için KOPRU_ENTEGRASYON=1.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["KOPRU_ENTEGRASYON"] == "1"), .serialized)
struct EngineIntegrationTests {
    @Test func createsBottleAndRunsCmd() async throws {
        let td = try TempDir()
        try Engine.checkRosetta()
        let engine = try Engine.locate(bundleResources: nil, environment: ProcessInfo.processInfo.environment,
                                       developmentFallback: Engine.developmentEngine)
        let runner = WineRunner(engine: engine, paths: td.paths)
        let bottle = try await BottleFactory(store: BottleStore(paths: td.paths), runner: runner)
            .create(name: "Entegrasyon", settings: .default, recipeId: nil)
        #expect(BottleStore.isWineBottle(bottle.url))

        let result = try await runner.run(.builtin("cmd", arguments: ["/c", "ver"]), in: bottle)
        #expect(result.exitCode == 0)
        let log = try String(contentsOf: td.paths.logFile(forBottleFolder: bottle.folderName), encoding: .utf8)
        #expect(log.contains("Windows"))

        await runner.killWineserver(prefix: bottle.url, settings: bottle.info.settings)
    }

    /// "Bottle hazırlanıyor" sırasında Durdur: wineboot'un bitmesi beklenmez, bottle'da Wine kalmaz.
    @Test func cancellingBottleCreationStopsWinebootQuickly() async throws {
        let td = try TempDir()
        let engine = try Engine.locate(bundleResources: nil, environment: ProcessInfo.processInfo.environment,
                                       developmentFallback: Engine.developmentEngine)
        let runner = WineRunner(engine: engine, paths: td.paths)
        let factory = BottleFactory(store: BottleStore(paths: td.paths), runner: runner)
        let task = Task { try await factory.create(name: "Durdur", settings: .default, recipeId: nil) }
        try await Task.sleep(for: .seconds(3))
        let clock = ContinuousClock()
        let start = clock.now
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("İptal bekleniyordu")
        } catch let failure as InstallFailure {
            #expect(failure.underlying is CancellationError)
            let elapsed = clock.now - start
            print("Durdur → dönüş: \(elapsed)")
            #expect(elapsed < .seconds(3))
            let bottle = try #require(failure.bottle)
            // wineserver -k ayrı görevde; kapanmasını en çok 5 sn bekle.
            let deadline = clock.now + .seconds(5)
            while WineServerStatus.isRunning(prefix: bottle.url) && clock.now < deadline {
                try await Task.sleep(for: .milliseconds(100))
            }
            print("Wine kapandı: \(clock.now - start)")
            #expect(!WineServerStatus.isRunning(prefix: bottle.url))
        }
    }
}
