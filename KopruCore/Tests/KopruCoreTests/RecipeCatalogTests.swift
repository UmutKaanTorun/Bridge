import Foundation
import Testing
@testable import KopruCore

struct RecipeCatalogTests {
    @Test func loadsJSONFilesSortedByName() throws {
        let td = try TempDir()
        let recipes = try td.dir("Recipes")
        let encoder = JSONEncoder()
        try encoder.encode(Recipe.fixture(id: "zeta", name: "Zeta")).write(to: recipes.appendingPathComponent("zeta.json"))
        try encoder.encode(Recipe.fixture(id: "alfa", name: "Alfa")).write(to: recipes.appendingPathComponent("alfa.json"))
        try td.file("Recipes/notlar.txt", "tarif değil")

        let catalog = try RecipeCatalog.load(recipesDirectory: recipes, filesDirectory: td.url.appendingPathComponent("RecipeFiles"))
        #expect(catalog.recipes.map(\.id) == ["alfa", "zeta"])
    }

    @Test func searchIsCaseAndDiacriticInsensitive() {
        let catalog = RecipeCatalog(recipes: [.fixture(id: "steam", name: "Steam"),
                                              .fixture(id: "cizim", name: "Çizim", summary: "Teknik çizim")],
                                    filesDirectory: URL(fileURLWithPath: "/tmp"))
        #expect(catalog.search("").map(\.id) == ["cizim", "steam"])
        #expect(catalog.search("STE").map(\.id) == ["steam"])
        #expect(catalog.search("ciz").map(\.id) == ["cizim"])
        #expect(catalog.search("teknik").map(\.id) == ["cizim"])
        #expect(catalog.search("yok").isEmpty)
    }

    @Test func findsRecipeByID() {
        let catalog = RecipeCatalog(recipes: [.fixture()], filesDirectory: URL(fileURLWithPath: "/tmp/RecipeFiles"))
        #expect(catalog.recipe(id: "steam")?.name == "Steam")
        #expect(catalog.recipe(id: nil) == nil)
        #expect(catalog.recipe(id: "yok") == nil)
        #expect(catalog.filesDirectory(for: .fixture()).path == "/tmp/RecipeFiles/steam")
    }

    @Test func detectsRecipeInBottle() throws {
        let td = try TempDir()
        let catalog = RecipeCatalog(recipes: [.fixture()], filesDirectory: td.url)
        let bottle = try td.dir("bottle")
        #expect(catalog.detect(in: bottle) == nil)
        try td.file("bottle/drive_c/Program Files (x86)/Steam/steam.exe")
        #expect(catalog.detect(in: bottle)?.id == "steam")
    }

    @Test func recipeWithoutDetectIsNeverDetected() throws {
        let td = try TempDir()
        let catalog = RecipeCatalog(recipes: [.fixture(detect: [])], filesDirectory: td.url)
        #expect(catalog.detect(in: try td.dir("bottle")) == nil)
    }
}
