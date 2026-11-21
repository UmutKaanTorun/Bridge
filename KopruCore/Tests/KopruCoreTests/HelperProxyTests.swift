import Foundation
import Testing
@testable import KopruCore

/// İçinde gerçek dosyanın adı (UTF-16) geçen sahte aracı; Tools/cef-araci'nin derlediği aracılar da öyle.
private func helperProxyFixture(_ helperName: String, _ label: String = "ARACI") -> Data {
    Data(label.utf8) + HelperProxy.marker(forHelperNamed: helperName)
}

struct HelperProxyTests {
    static let helperPath = "drive_c/Program Files/Rockstar Games/Social Club/SocialClubHelper.exe"

    @Test func realNameKeepsExtension() {
        #expect(HelperProxy.realName(forHelperNamed: "SocialClubHelper.exe") == "SocialClubHelper_gercek.exe")
        #expect(HelperProxy.realName(forHelperNamed: "a.b.EXE") == "a.b_gercek.EXE")
    }

    @Test func recognisesProxyByMarker() throws {
        let td = try TempDir()
        #expect(HelperProxy.isProxy(try td.file("a.exe", data: helperProxyFixture("SocialClubHelper.exe", "ESKI")),
                                    helperNamed: "SocialClubHelper.exe"))
        #expect(!HelperProxy.isProxy(try td.file("b.exe", data: Data(repeating: 0x4D, count: 100_000)),
                                     helperNamed: "SocialClubHelper.exe"))
        // Başka bir yardımcının aracısı bu yardımcının aracısı sayılmaz.
        #expect(!HelperProxy.isProxy(try td.file("c.exe", data: helperProxyFixture("steamwebhelper.exe")),
                                     helperNamed: "SocialClubHelper.exe"))
        #expect(!HelperProxy.isProxy(td.url.appendingPathComponent("olmayan.exe"), helperNamed: "x.exe"))
    }

    @Test func replacesHelperAndKeepsReal() throws {
        let td = try TempDir()
        let real = Data(repeating: 0x4D, count: 300_000)
        let helper = try td.file("bottle/\(Self.helperPath)", data: real)
        let proxy = try td.file("SocialClubHelper.exe", data: helperProxyFixture("SocialClubHelper.exe"))

        #expect(try HelperProxy.apply(helper: helper, proxyExecutable: proxy))

        let kept = helper.deletingLastPathComponent().appendingPathComponent("SocialClubHelper_gercek.exe")
        #expect(try Data(contentsOf: kept) == real)
        #expect(try Data(contentsOf: helper) == helperProxyFixture("SocialClubHelper.exe"))
        #expect(FileManager.default.isExecutableFile(atPath: helper.path))
        #expect(try HelperProxy.apply(helper: helper, proxyExecutable: proxy) == false)
    }

    /// Program kendini güncelleyince yeni gerçek dosyayı aracının üstüne yazar; eski gerçek dosya atılır.
    @Test func updatedRealHelperReplacesOldOne() throws {
        let td = try TempDir()
        let helper = try td.file("bottle/\(Self.helperPath)", data: Data(repeating: 1, count: 1000))
        let proxy = try td.file("SocialClubHelper.exe", data: helperProxyFixture("SocialClubHelper.exe"))
        try HelperProxy.apply(helper: helper, proxyExecutable: proxy)

        let newer = Data(repeating: 2, count: 2000)
        try newer.write(to: helper)
        #expect(try HelperProxy.apply(helper: helper, proxyExecutable: proxy))

        let kept = helper.deletingLastPathComponent().appendingPathComponent("SocialClubHelper_gercek.exe")
        #expect(try Data(contentsOf: kept) == newer)
        #expect(try Data(contentsOf: helper) == helperProxyFixture("SocialClubHelper.exe"))
    }

    /// Yeni sürüm aracı eskisinin yerine geçer; gerçek dosyaya dokunulmaz.
    @Test func olderProxyIsUpgraded() throws {
        let td = try TempDir()
        let helper = try td.file("bottle/\(Self.helperPath)", data: helperProxyFixture("SocialClubHelper.exe", "ESKI"))
        let kept = try td.file("bottle/drive_c/Program Files/Rockstar Games/Social Club/SocialClubHelper_gercek.exe",
                               data: Data(repeating: 7, count: 500))
        let proxy = try td.file("SocialClubHelper.exe", data: helperProxyFixture("SocialClubHelper.exe", "YENI"))

        #expect(try HelperProxy.apply(helper: helper, proxyExecutable: proxy))
        #expect(try Data(contentsOf: kept) == Data(repeating: 7, count: 500))
        #expect(try Data(contentsOf: helper) == helperProxyFixture("SocialClubHelper.exe", "YENI"))
    }

    /// Program (ör. Social Club) henüz kurulmamışsa bir şey yapılmaz; sonraki denemede yakalanır.
    @Test func missingHelperIsLeftAlone() throws {
        let td = try TempDir()
        let helper = td.url.appendingPathComponent("bottle/\(Self.helperPath)")
        let proxy = try td.file("SocialClubHelper.exe", data: helperProxyFixture("SocialClubHelper.exe"))
        #expect(try HelperProxy.apply(helper: helper, proxyExecutable: proxy) == false)
        #expect(!FileManager.default.fileExists(atPath: helper.path))
    }

    @Test func actionDecodesAndIsFileAction() throws {
        let json = #"{"action":"helperProxy","file":"drive_c/Program Files/Rockstar Games/Social Club/SocialClubHelper.exe"}"#
        let action = try JSONDecoder().decode(RecipeAction.self, from: Data(json.utf8))
        #expect(action == .helperProxy(file: Self.helperPath))
        #expect(action.isFileAction)
        #expect(try JSONDecoder().decode(RecipeAction.self, from: JSONEncoder().encode(action)) == action)
    }

    private func performer(_ td: TempDir) throws -> (RecipeActionPerformer, Bottle) {
        let runner = WineRunner(engine: try td.fakeEngine(), paths: td.paths, baseEnvironment: td.environment([:]))
        let catalog = RecipeCatalog(recipes: [.fixture()], filesDirectory: td.url.appendingPathComponent("RecipeFiles"))
        let bottle = try BottleStore(paths: td.paths).makeBottle(name: "Steam", settings: .default, recipeId: "steam")
        return (RecipeActionPerformer(runner: runner, catalog: catalog), bottle)
    }

    @Test func performerUsesRecipeFileNamedLikeHelper() async throws {
        let td = try TempDir()
        let (performer, bottle) = try performer(td)
        try td.file("RecipeFiles/steam/SocialClubHelper.exe", data: helperProxyFixture("SocialClubHelper.exe"))
        let helper = try td.file("AppSupport/Bottles/Steam/\(Self.helperPath)", data: Data(repeating: 3, count: 100))
        try await performer.perform([.helperProxy(file: Self.helperPath)], recipe: .fixture(), bottle: bottle)
        #expect(try Data(contentsOf: helper) == helperProxyFixture("SocialClubHelper.exe"))
    }

    @Test func performerRejectsPathsOutsideBottleAndMissingProxy() async throws {
        let td = try TempDir()
        let (performer, bottle) = try performer(td)
        await #expect(throws: RecipeActionError.unsafePath("../disari.exe")) {
            try await performer.perform([.helperProxy(file: "../disari.exe")], recipe: .fixture(), bottle: bottle)
        }
        let missing = td.url.appendingPathComponent("RecipeFiles/steam/SocialClubHelper.exe").path
        await #expect(throws: RecipeActionError.missingRecipeFile(missing)) {
            try await performer.perform([.helperProxy(file: Self.helperPath)], recipe: .fixture(), bottle: bottle)
        }
    }

    /// Kök `/private/…` ile verilince var olan kök standartlaşırken `/private`'ı kaybediyor, henüz var olmayan
    /// dosya kaybetmiyordu; dosya bottle dışı sanılıyordu (PlatformTrialTests'te /private/tmp altındaki bottle).
    @Test func pathResolutionToleratesPrivatePrefix() throws {
        let td = try TempDir()
        let bottle = URL(fileURLWithPath: "/private" + td.url.path, isDirectory: true)
        let url = try JSONFileValues.resolve("drive_c/henuz yok/dosya.exe", inBottleAt: bottle)
        #expect(url.lastPathComponent == "dosya.exe")
        #expect(throws: RecipeActionError.unsafePath("../disari.exe")) {
            try JSONFileValues.resolve("../disari.exe", inBottleAt: bottle)
        }
    }

    /// Yardımcı henüz yokken (Launcher Social Club'ı ilk açılışta kuruyor) beforeLaunch hata vermemeli.
    /// Geçici klasör (/var → /private/var) gibi bağlantılı yollarda var olmayan dosya bottle dışı sanılıyordu.
    @Test func performerSkipsHelperThatIsNotInstalledYet() async throws {
        let td = try TempDir()
        let (performer, bottle) = try performer(td)
        try td.file("RecipeFiles/steam/SocialClubHelper.exe", data: helperProxyFixture("SocialClubHelper.exe"))
        try await performer.perform([.helperProxy(file: Self.helperPath)], recipe: .fixture(), bottle: bottle)
        #expect(!FileManager.default.fileExists(atPath: bottle.url.appendingPathComponent(Self.helperPath).path))
    }
}
