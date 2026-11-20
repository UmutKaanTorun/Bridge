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
        try td.file("RecipeFiles/steam/steamwebhelper.exe", data: proxyFixture())
        let helper = try td.file("AppSupport/Bottles/Steam/drive_c/Program Files (x86)/Steam/bin/cef/cef.win64/steamwebhelper.exe",
                                 data: Data(repeating: 2, count: 600_000))
        try await performer.perform([.steamWebHelperProxy], recipe: .fixture(), bottle: bottle)
        #expect(isPaddedProxy(helper, proxy: proxyFixture(), size: 600_000))
    }

    /// Steam açılışta kendini güncelleyip tarayıcı dosyalarını sonradan yazar; koruma onları yakalamalı.
    @Test func keepApplyingReplacesHelperThatAppearsLater() async throws {
        let td = try TempDir()
        let (performer, bottle) = try setUp(td)
        try td.file("RecipeFiles/steam/steamwebhelper.exe", data: proxyFixture())
        let alive = Collected<Bool>()
        alive.add(true)
        let guardTask = Task {
            await performer.keepApplying([.steamWebHelperProxy, .registry(key: "HKCU\\A", name: "x", value: "y")],
                                         recipe: .fixture(), bottle: bottle, every: .milliseconds(50),
                                         while: { alive.all.last == true })
        }
        try await Task.sleep(for: .milliseconds(150))
        let helper = try td.file("AppSupport/Bottles/Steam/drive_c/Program Files (x86)/Steam/bin/cef/cef.win64/steamwebhelper.exe",
                                 data: Data(repeating: 3, count: 600_000))
        var replaced = false
        for _ in 0..<40 where !replaced {
            try await Task.sleep(for: .milliseconds(50))
            replaced = isPaddedProxy(helper, proxy: proxyFixture(), size: 600_000)
        }
        #expect(replaced)
        alive.add(false)
        await guardTask.value
        // Kayıt defteri gibi Wine çalıştıran eylemler korumada tekrarlanmaz.
        #expect(td.recordedLines().isEmpty)
    }

    @Test func keepApplyingStopsWhenBottleStops() async throws {
        let td = try TempDir()
        let (performer, bottle) = try setUp(td)
        let clock = ContinuousClock()
        let started = clock.now
        await performer.keepApplying([.steamWebHelperProxy], recipe: .fixture(), bottle: bottle,
                                     every: .milliseconds(50), while: { false })
        #expect(clock.now - started < .seconds(1))
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
