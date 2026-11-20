import Foundation
import Testing
@testable import KopruCore

struct RecipeInstallerTests {
    private func installer(_ td: TempDir, _ extra: [String: String] = [:]) throws -> RecipeInstaller {
        let runner = WineRunner(engine: try td.fakeEngine(), paths: td.paths, baseEnvironment: td.environment(extra))
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

        let commands = td.recordedLines().filter { !$0.hasPrefix("WINEPREFIX=") }
        #expect(commands.count == 3)
        #expect(commands[0] == "wine wineboot --init")
        #expect(commands[1] == "wine \(td.paths.downloads.appendingPathComponent("SteamSetup.exe").path) /S")
        #expect(commands[2].hasPrefix("wine reg add HKCU\\Software\\Wine\\DllOverrides /v gameoverlayrenderer64"))
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
