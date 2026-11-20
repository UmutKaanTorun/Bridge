import Foundation
import Testing
@testable import KopruCore

struct RecipeCatalogTests {
    static let sample = RecipeCatalog(
        recipes: [.fixture(id: "steam", name: "Steam", summary: "Oyun mağazası ve başlatıcısı", publisher: "Valve"),
                  .fixture(id: "winrar", name: "WinRAR", summary: "Arşivleme, RAR ve ZIP açma",
                           category: .office, rating: .perfect),
                  .fixture(id: "notepadpp", name: "Notepad++", summary: "Kod ve metin düzenleyici",
                           category: .office, rating: .perfect),
                  .fixture(id: "eski", name: "Eski Başlatıcı", summary: "Artık açılmıyor", rating: .broken)],
        upcoming: [UpcomingProgram(id: "logo", name: "Logo Go 3 / Tiger", publisher: "Logo Yazılım",
                                   summary: "Ön muhasebe ve ticari yazılım", category: .business, status: .testing)],
        filesDirectory: URL(fileURLWithPath: "/tmp/RecipeFiles"))

    @Test func sectionsSplitReadyAndUpcomingByName() {
        let sections = Self.sample.sections(matching: "", category: nil)
        #expect(sections.ready.map(\.name) == ["Notepad++", "Steam", "WinRAR"])
        #expect(sections.upcoming.map(\.name) == ["Eski Başlatıcı", "Logo Go 3 / Tiger"])
    }

    @Test func searchMatchesNameSummaryPublisherAndFoldsTurkish() {
        func names(_ query: String) -> [String] {
            let sections = Self.sample.sections(matching: query, category: nil)
            return (sections.ready + sections.upcoming).map(\.name)
        }
        #expect(names("NOTEPAD") == ["Notepad++"])
        #expect(names("valve") == ["Steam"])
        #expect(names("baslaticisi") == ["Steam"])
        #expect(names("arsivleme") == ["WinRAR"])
        #expect(names("  logo ") == ["Logo Go 3 / Tiger"])
        #expect(names("yok").isEmpty)
        #expect(Self.sample.sections(matching: "yok", category: nil).isEmpty)
    }

    @Test func categoryFilterCombinesWithSearch() {
        #expect(Self.sample.sections(matching: "", category: .office).ready.map(\.name) == ["Notepad++", "WinRAR"])
        #expect(Self.sample.sections(matching: "steam", category: .office).isEmpty)
        #expect(Self.sample.sections(matching: "", category: .business).upcoming.map(\.name) == ["Logo Go 3 / Tiger"])
    }

    @Test func countsAndCategoriesIgnoreSearch() {
        #expect(Self.sample.count(in: nil) == 5)
        #expect(Self.sample.count(in: .office) == 2)
        #expect(Self.sample.count(in: .engineering) == 0)
        #expect(Self.sample.categories == [.game, .business, .office])
    }

    @Test func findsEntryByID() {
        #expect(Self.sample.entry(id: "recipe:steam")?.name == "Steam")
        #expect(Self.sample.entry(id: "upcoming:logo")?.isReady == false)
        #expect(Self.sample.entry(id: "recipe:eski")?.isReady == false)
        #expect(Self.sample.entry(id: nil) == nil)
        #expect(Self.sample.entry(id: "recipe:yok") == nil)
    }

    @Test func brokenRecipeFileDoesNotEmptyCatalog() throws {
        let td = try TempDir()
        let recipes = try td.dir("Recipes")
        try JSONEncoder().encode(Recipe.fixture(id: "alfa", name: "Alfa")).write(to: recipes.appendingPathComponent("alfa.json"))
        try td.file("Recipes/bozuk.json", "{")
        let catalog = try RecipeCatalog.load(recipesDirectory: recipes, filesDirectory: td.url)
        #expect(catalog.recipes.map(\.id) == ["alfa"])
        #expect(catalog.problems.count == 1)
        #expect(catalog.problems.first?.hasPrefix("bozuk.json") == true)
    }

    @Test func loadsUpcomingAndDropsEntriesThatHaveRecipes() throws {
        let td = try TempDir()
        let recipes = try td.dir("Recipes")
        try JSONEncoder().encode(Recipe.fixture()).write(to: recipes.appendingPathComponent("steam.json"))
        let upcoming = try td.file("upcoming.json", """
        [{"id":"steam","name":"Steam","summary":"x","category":"game","status":"testing"},
         {"id":"gog-galaxy","name":"GOG Galaxy","publisher":"GOG","summary":"Oyun mağazası","category":"game","status":"testing"},
         {"id":"epic","name":"Epic Games Launcher","summary":"Oyun mağazası","category":"game","status":"broken","note":"Takılıyor."}]
        """)
        let catalog = try RecipeCatalog.load(recipesDirectory: recipes, filesDirectory: td.url, upcomingFile: upcoming)
        #expect(catalog.upcoming.map(\.id) == ["epic", "gog-galaxy"])
        #expect(catalog.upcoming.first?.note == "Takılıyor.")
        #expect(catalog.upcoming.last?.publisher == "GOG")
        #expect(catalog.problems.isEmpty)
    }

    @Test func missingUpcomingFileLeavesListEmpty() throws {
        let td = try TempDir()
        let catalog = try RecipeCatalog.load(recipesDirectory: try td.dir("Recipes"), filesDirectory: td.url,
                                             upcomingFile: td.url.appendingPathComponent("yok.json"))
        #expect(catalog.upcoming.isEmpty)
        #expect(catalog.problems.count == 1)
    }

    @Test func iconURLOnlyWhenFileExists() throws {
        let td = try TempDir()
        let catalog = RecipeCatalog(recipes: [.fixture()], filesDirectory: td.url)
        #expect(catalog.iconURL(for: "steam") == nil)
        try td.file("steam/icon.png", "png")
        #expect(catalog.iconURL(for: "steam")?.lastPathComponent == "icon.png")
    }

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
