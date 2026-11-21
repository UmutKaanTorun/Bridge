import Foundation

/// Uygulamanın içindeki tarifler ve "Yakında" listesi.
public struct RecipeCatalog: Sendable {
    public let recipes: [Recipe]
    /// Tarifi henüz olmayan, test edilen programlar; tarifle aynı id'yi taşıyanlar elenmiş.
    public let upcoming: [UpcomingProgram]
    /// Tariflere ait ek dosyalar: <filesDirectory>/<tarif id>/...
    public let filesDirectory: URL
    /// Okunamayan dosyalar ve nedenleri; uygulama günlüğe yazar.
    public let problems: [String]

    public init(recipes: [Recipe], upcoming: [UpcomingProgram] = [], filesDirectory: URL, problems: [String] = []) {
        self.recipes = recipes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let recipeIDs = Set(recipes.map(\.id))
        self.upcoming = upcoming
            .filter { !recipeIDs.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        self.filesDirectory = filesDirectory
        self.problems = problems
    }

    /// Klasördeki .json tariflerini tek tek okur; okunamayan dosya atlanır ve `problems`'a yazılır.
    /// `upcomingFile` yoksa ya da okunamazsa "Yakında" listesi boş kalır.
    public static func load(recipesDirectory: URL, filesDirectory: URL, upcomingFile: URL? = nil) throws -> RecipeCatalog {
        let files = try FileManager.default
            .contentsOfDirectory(at: recipesDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "json" }
        let decoder = JSONDecoder()
        var recipes: [Recipe] = []
        var problems: [String] = []
        for file in files {
            do {
                recipes.append(try decoder.decode(Recipe.self, from: Data(contentsOf: file)))
            } catch {
                problems.append("\(file.lastPathComponent): \(error)")
            }
        }
        var upcoming: [UpcomingProgram] = []
        if let upcomingFile {
            do {
                upcoming = try decoder.decode([UpcomingProgram].self, from: Data(contentsOf: upcomingFile))
            } catch {
                problems.append("\(upcomingFile.lastPathComponent): \(error)")
            }
        }
        return RecipeCatalog(recipes: recipes, upcoming: upcoming, filesDirectory: filesDirectory, problems: problems)
    }

    public func recipe(id: String?) -> Recipe? {
        guard let id else { return nil }
        return recipes.first { $0.id == id }
    }

    public func filesDirectory(for recipe: Recipe) -> URL {
        filesDirectory.appendingPathComponent(recipe.id, isDirectory: true)
    }

    /// Tarifin simgesi (RecipeFiles/<id>/icon.png); dosya yoksa nil.
    public func iconURL(for recipeID: String) -> URL? {
        let url = filesDirectory.appendingPathComponent(recipeID, isDirectory: true).appendingPathComponent("icon.png")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Bottle'da `detect` dosyalarının hepsi bulunan ilk tarif.
    public func detect(in bottleURL: URL) -> Recipe? {
        recipes.first { !$0.detect.isEmpty && $0.isInstalled(in: bottleURL) }
    }

    // MARK: Kur sayfası

    private var allEntries: [CatalogEntry] {
        recipes.map(CatalogEntry.recipe) + upcoming.map(CatalogEntry.upcoming)
    }

    /// Süzgeçten geçen kartlar ada göre sıralı: hazır tarifler ve "Yakında" (çalışmayan tarifler + tarifsizler).
    public func sections(matching query: String, category: RecipeCategory?) -> CatalogSections {
        let folded = SearchText.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        let entries = allEntries
            .filter { (category == nil || $0.category == category) && $0.matches(folded: folded) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return CatalogSections(ready: entries.filter(\.isReady), upcoming: entries.filter { !$0.isReady })
    }

    /// Kur sayfasındaki oyun platformları (oyun kategorisindeki tarifler): önce iyi çalışanlar, sonra ada göre.
    public func platforms(matching query: String) -> [Recipe] {
        let folded = SearchText.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return recipes
            .filter { $0.category == .game && CatalogEntry.recipe($0).matches(folded: folded) }
            .sorted { ($0.rating.rank, $0.name.lowercased()) < ($1.rating.rank, $1.name.lowercased()) }
    }

    /// Kategori kapsülündeki sayı (aramadan bağımsız); nil = hepsi.
    public func count(in category: RecipeCategory?) -> Int {
        allEntries.filter { category == nil || $0.category == category }.count
    }

    /// En az bir kartı olan kategoriler, `allCases` sırasıyla.
    public var categories: [RecipeCategory] {
        RecipeCategory.allCases.filter { count(in: $0) > 0 }
    }

    public func entry(id: CatalogEntry.ID?) -> CatalogEntry? {
        guard let id else { return nil }
        return allEntries.first { $0.id == id }
    }
}
