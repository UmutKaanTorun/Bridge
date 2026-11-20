import Foundation
import Testing
@testable import KopruCore

struct RecipeActionPerformerTests {
    private func setUp(_ td: TempDir, _ extra: [String: String] = [:]) throws -> (RecipeActionPerformer, Bottle) {
        let runner = WineRunner(engine: try td.fakeEngine(), paths: td.paths, baseEnvironment: td.environment(extra))
        let catalog = RecipeCatalog(recipes: [.fixture()], filesDirectory: td.url.appendingPathComponent("RecipeFiles"))
        let bottle = try BottleStore(paths: td.paths).makeBottle(name: "Steam", settings: .default, recipeId: "steam")
        return (RecipeActionPerformer(runner: runner, catalog: catalog), bottle)
    }

    @Test func registryArguments() {
        #expect(RecipeActionPerformer.registryArguments(key: "HKCU\\Software\\Wine\\DllOverrides", name: "gameoverlayrenderer64", value: "")
                == ["add", "HKCU\\Software\\Wine\\DllOverrides", "/v", "gameoverlayrenderer64", "/t", "REG_SZ", "/d", "", "/f"])
    }

    @Test func registryActionRunsReg() async throws {
        let td = try TempDir()
        let (performer, bottle) = try setUp(td)
        try await performer.perform([.registry(key: "HKCU\\Software\\Wine\\DllOverrides", name: "gameoverlayrenderer64", value: "")],
                                    recipe: .fixture(), bottle: bottle)
        #expect(td.recordedLines().first?.hasPrefix("wine reg add HKCU\\Software\\Wine\\DllOverrides /v gameoverlayrenderer64 /t REG_SZ /d") == true)
    }

    @Test func registryFailureThrows() async throws {
        let td = try TempDir()
        let (performer, bottle) = try setUp(td, ["CIKIS": "1"])
        await #expect(throws: RecipeActionError.registryFailed(name: "x", exitCode: 1)) {
            try await performer.perform([.registry(key: "HKCU\\A", name: "x", value: "y")], recipe: .fixture(), bottle: bottle)
        }
    }

    @Test func proxyActionUsesRecipeFiles() async throws {
        let td = try TempDir()
        let (performer, bottle) = try setUp(td)
        try td.file("RecipeFiles/steam/steamwebhelper.exe", "ARACI")
        let helper = try td.file("AppSupport/Bottles/Steam/drive_c/Program Files (x86)/Steam/bin/cef/cef.win64/steamwebhelper.exe",
                                 data: Data(repeating: 2, count: 600_000))
        try await performer.perform([.steamWebHelperProxy], recipe: .fixture(), bottle: bottle)
        #expect(try String(contentsOf: helper, encoding: .utf8) == "ARACI")
    }

    @Test func missingProxyFileThrows() async throws {
        let td = try TempDir()
        let (performer, bottle) = try setUp(td)
        let expected = td.url.appendingPathComponent("RecipeFiles/steam/steamwebhelper.exe").path
        await #expect(throws: RecipeActionError.missingRecipeFile(expected)) {
            try await performer.perform([.steamWebHelperProxy], recipe: .fixture(), bottle: bottle)
        }
    }
}
