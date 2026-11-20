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

    @Test func ratingLabels() {
        #expect(RecipeRating.works.label == "Çalışıyor")
        #expect(RecipeRating.partial.label == "Kısmen çalışıyor")
        #expect(RecipeRating.broken.label == "Çalışmıyor")
    }
}
