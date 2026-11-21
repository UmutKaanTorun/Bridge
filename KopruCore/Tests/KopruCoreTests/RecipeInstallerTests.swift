import Foundation
import Testing
@testable import KopruCore

struct RecipeInstallerTests {
    private func installer(_ td: TempDir, _ extra: [String: String] = [:]) throws -> RecipeInstaller {
        let defaults = ["KURULAN": "drive_c/Program Files (x86)/Steam/steam.exe"]
        let runner = WineRunner(engine: try td.fakeEngine(), paths: td.paths,
                                baseEnvironment: td.environment(defaults.merging(extra) { _, new in new }))
        let store = BottleStore(paths: td.paths)
        let catalog = RecipeCatalog(recipes: [], filesDirectory: td.url.appendingPathComponent("RecipeFiles"))
        return RecipeInstaller(factory: BottleFactory(store: store, runner: runner),
                               runner: runner,
                               actions: RecipeActionPerformer(runner: runner, catalog: catalog),
                               downloader: Downloader(),
                               downloadsDirectory: td.paths.downloads)
    }

    private func recipe(_ td: TempDir, sha256: String? = nil) throws -> Recipe {
        let setup = try td.file("kaynak/SteamSetup.exe", "abc")
        return .fixture(installerURL: setup, sha256: sha256,
                        afterInstall: [.registry(key: "HKCU\\Software\\Wine\\DllOverrides", name: "gameoverlayrenderer64", value: "")])
    }

    @Test func installsRecipeStepByStep() async throws {
        let td = try TempDir()
        let events = Collected<InstallEvent>()
        let bottle = try await installer(td).install(try recipe(td), bottleName: "Steam") { events.add($0) }

        #expect(bottle.info.name == "Steam")
        #expect(bottle.info.recipeId == "steam")
        #expect(bottle.info.settings.virtualDesktop == .auto)
        let steps = events.all.filter { if case .progress = $0 { false } else { true } }
        #expect(steps == [.started(.preparing), .bottleCreated(bottle), .finished(.preparing),
                          .started(.downloading), .finished(.downloading),
                          .started(.installing), .finished(.installing),
                          .started(.configuring), .finished(.configuring)])

        // Kurulum penceresi Dock'ta tarifin adıyla görünür; yalnızca kurulum programına verilir.
        #expect(td.recordedLines().filter { $0.hasPrefix("KOPRU_APP_NAME=") } == ["KOPRU_APP_NAME=Steam"])
        let commands = td.recordedLines().filter { !$0.hasPrefix("WINEPREFIX=") && !$0.hasPrefix("KOPRU_APP_NAME=") }
        #expect(commands.count == 4)
        #expect(commands[0] == "wine wineboot --init")
        // Kayıt defteri ancak wineserver kapanınca diske yazılır; bottle tamamlanmış sayılmadan beklenir.
        #expect(commands[1] == "wineserver -w")
        #expect(commands[2] == "wine \(td.paths.downloads.appendingPathComponent("SteamSetup.exe").path) /S")
        #expect(commands[3].hasPrefix("wine reg add HKCU\\Software\\Wine\\DllOverrides /v gameoverlayrenderer64"))
    }

    @Test func winebootFailureKeepsHalfBottle() async throws {
        let td = try TempDir()
        do {
            _ = try await installer(td, ["HATALI": "wineboot"]).install(try recipe(td), bottleName: "Steam") { _ in }
            Issue.record("Hata bekleniyordu")
        } catch let failure as InstallFailure {
            #expect(failure.step == .preparing)
            #expect(failure.bottle?.info.name == "Steam")
            #expect(failure.underlying as? InstallError == .prefixInitFailed(exitCode: 7))
        }
    }

    @Test func installerFailureReportsStep() async throws {
        let td = try TempDir()
        do {
            _ = try await installer(td, ["HATALI": "/S"]).install(try recipe(td), bottleName: "Steam") { _ in }
            Issue.record("Hata bekleniyordu")
        } catch let failure as InstallFailure {
            #expect(failure.step == .installing)
            #expect(failure.bottle != nil)
            #expect(failure.underlying as? InstallError == .installerFailed(exitCode: 7))
            #expect(failure.localizedDescription == "Kurulum programı hata ile bitti (çıkış kodu 7).")
        }
    }

    @Test func cancellingStopsInstallerAndKillsWineserver() async throws {
        let td = try TempDir()
        let installer = try installer(td, ["UYKU": "2"])
        let recipe = try recipe(td)
        let started = Collected<InstallEvent>()
        let task = Task { try await installer.install(recipe, bottleName: "Steam") { started.add($0) } }
        // wineboot da 2 sn uyur; kurulum programı başlayana kadar bekle, sonra durdur.
        while !started.all.contains(.started(.installing)) { try await Task.sleep(for: .milliseconds(50)) }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Hata bekleniyordu")
        } catch let failure as InstallFailure {
            #expect(failure.step == .installing)
            #expect(failure.bottle != nil)
            #expect(failure.underlying is CancellationError)
        }
        try await Task.sleep(for: .milliseconds(200))
        #expect(td.recordedLines().contains("wineserver -k"))
        #expect(!started.all.contains(.started(.configuring)))
    }

    @Test func cancellingWhilePreparingStopsWinebootAtOnce() async throws {
        let td = try TempDir()
        let installer = try installer(td, ["UYKU": "5"])
        let recipe = try recipe(td)
        let events = Collected<InstallEvent>()
        let task = Task { try await installer.install(recipe, bottleName: "Steam") { events.add($0) } }
        // wineboot 5 sn uyur; başladığı an durdur.
        while !td.recordedLines().contains("wine wineboot --init") { try await Task.sleep(for: .milliseconds(20)) }
        let clock = ContinuousClock()
        let start = clock.now
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Hata bekleniyordu")
        } catch let failure as InstallFailure {
            #expect(failure.step == .preparing)
            #expect(failure.bottle?.info.name == "Steam")
            #expect(failure.underlying is CancellationError)
        }
        // Durdur, wineboot'un ve kayıt defteri beklemesinin bitmesini beklemez.
        #expect(clock.now - start < .seconds(2))
        // wineserver -k ayrı görevde çalışır; testler paralel koşarken sahte betik geç başlayabilir.
        let deadline = clock.now + .seconds(3)
        while !td.recordedLines().contains("wineserver -k") && clock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(td.recordedLines().contains("wineserver -k"))
        #expect(!td.recordedLines().contains("wineserver -w"))
        #expect(!events.all.contains(.started(.downloading)))
    }

    @Test func installerThatWritesNothingFails() async throws {
        let td = try TempDir()
        do {
            _ = try await installer(td, ["KURULAN": ""]).install(try recipe(td), bottleName: "Steam") { _ in }
            Issue.record("Hata bekleniyordu")
        } catch let failure as InstallFailure {
            #expect(failure.step == .installing)
            #expect(failure.bottle != nil)
            #expect(failure.underlying as? InstallError == .programMissing("Steam"))
        }
    }

    @Test func checksumFailureStopsAtDownload() async throws {
        let td = try TempDir()
        do {
            _ = try await installer(td).install(try recipe(td, sha256: String(repeating: "0", count: 64)), bottleName: "Steam") { _ in }
            Issue.record("Hata bekleniyordu")
        } catch let failure as InstallFailure {
            #expect(failure.step == .downloading)
            #expect(failure.underlying is DownloadError)
        }
    }

    @Test func duplicateNameFailsBeforeCreatingAnything() async throws {
        let td = try TempDir()
        _ = try BottleStore(paths: td.paths).makeBottle(name: "Steam", settings: .default, recipeId: nil)
        do {
            _ = try await installer(td).install(try recipe(td), bottleName: "Steam") { _ in }
            Issue.record("Hata bekleniyordu")
        } catch let failure as InstallFailure {
            #expect(failure.step == .preparing)
            #expect(failure.bottle == nil)
            #expect(failure.underlying as? BottleStoreError == .nameTaken("Steam"))
        }
    }

    @Test func stepTitles() {
        #expect(InstallStep.allCases.map(\.title) == ["Bottle hazırlanıyor", "İndiriliyor", "Kuruluyor", "Ayarlanıyor"])
    }
}
