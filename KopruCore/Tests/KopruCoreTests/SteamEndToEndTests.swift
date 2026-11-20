import Foundation
import Testing
@testable import KopruCore

/// Gerçek motor ve gerçek ağla sıfırdan Steam kurulumu. Steam ilk açılışta kendini (önce 32, sonra 64 bit
/// istemciye) güncellerken tarayıcı dosyalarını yeniden yazar; koruma aracıyı yerinde tutmalı ve giriş
/// penceresi tek süreçli tarayıcıyla açılmalı. Birkaç yüz MB indirir, birkaç dakika sürer, ekranda Steam
/// pencereleri açar. Çalıştırmak için KOPRU_STEAM_E2E=1.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["KOPRU_STEAM_E2E"] == "1"), .serialized)
struct SteamEndToEndTests {
    static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // KopruCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // KopruCore
        .deletingLastPathComponent()   // depo kökü

    @Test(.timeLimit(.minutes(15)))
    func freshSteamInstallShowsLoginWindow() async throws {
        let td = try TempDir()
        let engine = try Engine.locate(bundleResources: nil, environment: ProcessInfo.processInfo.environment,
                                       developmentFallback: Engine.developmentEngine)
        let runner = WineRunner(engine: engine, paths: td.paths)
        let catalog = try RecipeCatalog.load(recipesDirectory: Self.repo.appendingPathComponent("Resources/Recipes"),
                                             filesDirectory: Self.repo.appendingPathComponent("Resources/RecipeFiles"))
        let recipe = try #require(catalog.recipe(id: "steam"))
        let actions = RecipeActionPerformer(runner: runner, catalog: catalog)
        let installer = RecipeInstaller(factory: BottleFactory(store: BottleStore(paths: td.paths), runner: runner),
                                        runner: runner, actions: actions, downloader: Downloader(),
                                        downloadsDirectory: td.paths.downloads)
        let bottle = try await installer.install(recipe, bottleName: "Steam E2E") { _ in }

        // AppModel.start ile aynı sıra: beforeLaunch → koruma → açılış.
        try await actions.perform(recipe.beforeLaunch, recipe: recipe, bottle: bottle)
        let prefix = bottle.url
        let guardTask = Task {
            await actions.keepApplying(recipe.whileRunning ?? [], recipe: recipe, bottle: bottle, while: {
                runner.isRunning(bottle) || WineServerStatus.isRunning(prefix: prefix)
            })
        }
        let launch = Task {
            try await runner.run(.windowsPath(recipe.launch.windowsPath, arguments: recipe.launch.arguments(forBottleAt: bottle.url)),
                                 in: bottle, desktopSize: PixelSize(width: 1280, height: 800))
        }

        let steamLogs = bottle.driveC.appendingPathComponent("Program Files (x86)/Steam/logs")
        let read = { (name: String) in (try? String(contentsOf: steamLogs.appendingPathComponent(name), encoding: .utf8)) ?? "" }
        let bottleLog = { (try? String(contentsOf: td.paths.logFile(forBottleFolder: bottle.folderName), encoding: .utf8)) ?? "" }
        let isBroken = {
            bottleLog().contains("cross-process swapchain not supported")
                || read("cef_log.txt").contains("eglCreateWindowSurface failed")
                || read("cef_log.txt").contains("Could not create additional swap chains")
        }

        // 64 bit istemcinin giriş penceresi açılana (ya da tarayıcı bozulana) kadar bekle.
        let deadline = ContinuousClock.now + .seconds(600)
        var loginShown = false
        while ContinuousClock.now < deadline && !loginShown && !isBroken() {
            try await Task.sleep(for: .seconds(2))
            let web = read("webhelper.txt")
            loginShown = web.contains("cef.win64") || read("bootstrap_log.txt").contains("cef.win64")
                ? web.contains("DesktopLoginWindow") && web.contains("Created window")
                : false
        }
        try await Task.sleep(for: .seconds(8))   // hata satırları pencereden birkaç saniye sonra düşer

        let cef = read("cef_log.txt")
        #expect(loginShown, "Giriş penceresi açılmadı")
        #expect(!isBroken(), "Tarayıcı aracısız açıldı (cross-process swapchain)")
        #expect(cef.contains("single process mode"), "Tarayıcı tek süreç modunda değil")
        let cef64 = bottle.driveC.appendingPathComponent("Program Files (x86)/Steam/bin/cef/cef.win64")
        let proxy = try Data(contentsOf: catalog.filesDirectory(for: recipe).appendingPathComponent("steamwebhelper.exe"))
        let realSize = try #require(try? FileManager.default.attributesOfItem(
            atPath: cef64.appendingPathComponent("steamwebhelper_gercek.exe").path)[.size] as? NSNumber).intValue
        #expect(isPaddedProxy(cef64.appendingPathComponent("steamwebhelper.exe"), proxy: proxy, size: realSize))
        // Boyut denetimi artık geçmeli: Steam aracıyı "bozuk" sayıp yeniden kurmamalı.
        #expect(!read("bootstrap_log.txt").contains("steamwebhelper.exe is "), "Steam aracının boyutunu tutarsız buldu")

        await runner.stop(bottle, shutdown: .windowsPath(recipe.launch.windowsPath, arguments: recipe.launch.shutdownArguments ?? []),
                          grace: .seconds(10))
        guardTask.cancel()
        await guardTask.value
        _ = try? await launch.value
    }
}
