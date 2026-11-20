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
}
