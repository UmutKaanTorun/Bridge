import Foundation
import Testing
@testable import KopruCore

struct RecipeTests {
    /// Depodaki gerçek Steam tarifi.
    static let steamJSON = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // KopruCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // KopruCore
        .deletingLastPathComponent()   // depo kökü
        .appendingPathComponent("Resources/Recipes/steam.json")

    @Test func decodesSteamRecipe() throws {
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(contentsOf: Self.steamJSON))
        #expect(recipe.id == "steam")
        #expect(recipe.rating == .works)
        #expect(recipe.bottle.settings.virtualDesktop == .auto)
        #expect(recipe.installer.sha256 == nil)
        #expect(recipe.installer.arguments == ["/S"])
        #expect(recipe.afterInstall == [.registry(key: "HKCU\\Software\\Wine\\DllOverrides", name: "gameoverlayrenderer64", value: "")])
        #expect(recipe.beforeLaunch == [.steamWebHelperProxy])
        #expect(recipe.launch.windowsPath == "C:\\Program Files (x86)\\Steam\\steam.exe")
        #expect(recipe.launch.arguments == ["-noverifyfiles", "-no-cef-sandbox"])
        #expect(recipe.launch.shutdownArguments == ["-shutdown"])
        #expect(recipe.hideShortcuts == ["Steam/Steam.lnk"])
        #expect(recipe.whileRunning == [.steamWebHelperProxy])
        #expect(recipe.launch.readyFile == "drive_c/Program Files (x86)/Steam/SteamUI.dll")
        #expect(recipe.launch.firstRunArguments == ["-no-cef-sandbox"])
    }

    @Test func whileRunningIsOptional() throws {
        let data = try JSONEncoder().encode(Recipe.fixture())
        #expect(!String(decoding: data, as: UTF8.self).contains("whileRunning"))
        #expect(try JSONDecoder().decode(Recipe.self, from: data).whileRunning == nil)
    }

    @Test func rejectsUnknownAction() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RecipeAction.self, from: Data(#"{"action":"formatC"}"#.utf8))
        }
    }

    @Test func actionRoundTrip() throws {
        let actions: [RecipeAction] = [.registry(key: "HKCU\\X", name: "a", value: "b"), .steamWebHelperProxy]
        let data = try JSONEncoder().encode(actions)
        #expect(try JSONDecoder().decode([RecipeAction].self, from: data) == actions)
    }

    @Test func ratingLabels() throws {
        #expect(RecipeRating.perfect.label == "Sorunsuz")
        #expect(RecipeRating.works.label == "Çalışıyor")
        #expect(RecipeRating.partial.label == "Kısmen çalışıyor")
        #expect(RecipeRating.broken.label == "Şimdilik çalışmıyor")
        #expect(try JSONDecoder().decode(RecipeRating.self, from: Data(#""perfect""#.utf8)) == .perfect)
    }

    @Test func categoryLabelsAndSymbols() {
        #expect(RecipeCategory.allCases.map(\.label) == ["Oyun", "İş ve muhasebe", "Mühendislik", "Ofis"])
        #expect(RecipeCategory.allCases.map(\.symbolName) == ["gamecontroller", "building.columns", "ruler", "doc.text"])
    }

    @Test func decodesSteamDisplayFields() throws {
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(contentsOf: Self.steamJSON))
        #expect(recipe.category == .game)
        #expect(recipe.publisher == "Valve")
        #expect(recipe.summary == "Oyun mağazası ve başlatıcısı")
        #expect(recipe.testedOn == RecipeTestInfo(date: "2026-11-20", hardware: "Apple M3", macOS: "26.6"))
        #expect(recipe.highlights?.map(\.title) == ["Tarayıcı yardımcısı düzeltmesi", "Sanal masaüstü",
                                                    "Steam katmanı kapalı", "MSync açık"])
        #expect(recipe.verdict?.isEmpty == false)
        #expect(recipe.downloadNote?.isEmpty == false)
    }

    @Test func displayFieldsAreOptional() throws {
        let data = try JSONEncoder().encode(Recipe.fixture())
        let text = String(decoding: data, as: UTF8.self)
        for key in ["publisher", "verdict", "testedOn", "downloadNote", "highlights"] {
            #expect(!text.contains(key), "\(key) boşken yazılmamalı")
        }
        let recipe = try JSONDecoder().decode(Recipe.self, from: data)
        #expect(recipe.publisher == nil)
        #expect(recipe.verdict == nil)
        #expect(recipe.testedOn == nil)
        #expect(recipe.downloadNote == nil)
        #expect(recipe.highlights == nil)
    }

    @Test func rejectsUnknownCategory() throws {
        let text = String(decoding: try JSONEncoder().encode(Recipe.fixture()), as: UTF8.self)
            .replacingOccurrences(of: #""category":"game""#, with: #""category":"mutfak""#)
        #expect(text.contains("mutfak"))
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Recipe.self, from: Data(text.utf8))
        }
    }

    @Test func testInfoSummary() {
        #expect(RecipeTestInfo(date: "2026-11-20", hardware: "Apple M3", macOS: "26.6").summary
                == "20 Kas 2026 · Apple M3 · macOS 26.6")
        #expect(RecipeTestInfo(date: "yakında", hardware: "Apple M3", macOS: "26.6").summary
                == "yakında · Apple M3 · macOS 26.6")
    }
}
