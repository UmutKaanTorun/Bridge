import Foundation

/// Uygulamanın içindeki tarifler.
public struct RecipeCatalog: Sendable {
    public let recipes: [Recipe]
    /// Tariflere ait ek dosyalar: <filesDirectory>/<tarif id>/...
    public let filesDirectory: URL

    public init(recipes: [Recipe], filesDirectory: URL) {
        self.recipes = recipes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        self.filesDirectory = filesDirectory
    }

    /// Klasördeki bütün .json tariflerini okur.
    public static func load(recipesDirectory: URL, filesDirectory: URL) throws -> RecipeCatalog {
        let files = try FileManager.default
            .contentsOfDirectory(at: recipesDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "json" }
        let decoder = JSONDecoder()
        let recipes = try files.map { try decoder.decode(Recipe.self, from: Data(contentsOf: $0)) }
        return RecipeCatalog(recipes: recipes, filesDirectory: filesDirectory)
    }

    /// Ad ve özette büyük/küçük harf ve aksan duyarsız arama; boş sorgu hepsini döndürür.
    public func search(_ query: String) -> [Recipe] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return recipes }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return recipes.filter {
            $0.name.range(of: q, options: options) != nil || $0.summary.range(of: q, options: options) != nil
        }
    }

    public func recipe(id: String?) -> Recipe? {
        guard let id else { return nil }
        return recipes.first { $0.id == id }
    }

    public func filesDirectory(for recipe: Recipe) -> URL {
        filesDirectory.appendingPathComponent(recipe.id, isDirectory: true)
    }

    /// Bottle'da `detect` dosyalarının hepsi bulunan ilk tarif.
    public func detect(in bottleURL: URL) -> Recipe? {
        recipes.first { recipe in
            !recipe.detect.isEmpty && recipe.detect.allSatisfy {
                FileManager.default.fileExists(atPath: bottleURL.appendingPathComponent($0).path)
            }
        }
    }
}
