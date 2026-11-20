import Foundation
import Testing
@testable import KopruCore

/// Depodaki gerçek tarif ve katalog dosyaları.
struct RepositoryCatalogTests {
    static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // KopruCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // KopruCore
        .deletingLastPathComponent()   // depo kökü
        .appendingPathComponent("Resources", isDirectory: true)

    static func load() throws -> RecipeCatalog {
        try RecipeCatalog.load(recipesDirectory: resources.appendingPathComponent("Recipes"),
                               filesDirectory: resources.appendingPathComponent("RecipeFiles"),
                               upcomingFile: resources.appendingPathComponent("Catalog/upcoming.json"))
    }

    @Test func everyFileLoads() throws {
        let catalog = try Self.load()
        #expect(catalog.problems.isEmpty, "\(catalog.problems)")
        #expect(!catalog.recipes.isEmpty)
        #expect(!catalog.upcoming.isEmpty)
    }

    @Test func recipesCarryDisplayFieldsAndIcons() throws {
        let catalog = try Self.load()
        for recipe in catalog.recipes {
            #expect(recipe.publisher != nil, "\(recipe.id): yayıncı yok")
            #expect(recipe.verdict != nil, "\(recipe.id): açıklama yok")
            #expect(recipe.testedOn != nil, "\(recipe.id): test bilgisi yok")
            if recipe.rating != .broken {
                #expect(catalog.iconURL(for: recipe.id) != nil, "\(recipe.id): icon.png yok")
            }
        }
    }

    @Test func upcomingIDsAreUniqueAndNotRecipes() throws {
        let file = Self.resources.appendingPathComponent("Catalog/upcoming.json")
        let ids = try JSONDecoder().decode([UpcomingProgram].self, from: Data(contentsOf: file)).map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(Set(try Self.load().recipes.map(\.id)).isDisjoint(with: ids))
    }
}
