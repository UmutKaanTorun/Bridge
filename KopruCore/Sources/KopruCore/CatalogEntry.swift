import Foundation

/// Kur sayfasındaki bir kart: tarif ya da "Yakında" girdisi.
public enum CatalogEntry: Identifiable, Hashable, Sendable {
    case recipe(Recipe)
    case upcoming(UpcomingProgram)

    public var id: String {
        switch self {
        case let .recipe(recipe): "recipe:\(recipe.id)"
        case let .upcoming(program): "upcoming:\(program.id)"
        }
    }

    public var name: String {
        switch self {
        case let .recipe(recipe): recipe.name
        case let .upcoming(program): program.name
        }
    }

    public var publisher: String? {
        switch self {
        case let .recipe(recipe): recipe.publisher
        case let .upcoming(program): program.publisher
        }
    }

    public var summary: String {
        switch self {
        case let .recipe(recipe): recipe.summary
        case let .upcoming(program): program.summary
        }
    }

    public var category: RecipeCategory {
        switch self {
        case let .recipe(recipe): recipe.category
        case let .upcoming(program): program.category
        }
    }

    /// "Kurulmaya hazır" bölümünde mi? Çalışmayan tarifler ve tarifsiz girdiler "Yakında"dadır.
    public var isReady: Bool {
        if case let .recipe(recipe) = self { recipe.rating != .broken } else { false }
    }

    /// Katlanmış sorgu adda, özette ya da yayıncıda geçiyor mu? Boş sorgu her şeyle eşleşir.
    func matches(folded query: String) -> Bool {
        query.isEmpty || [name, summary, publisher ?? ""].contains { SearchText.fold($0).contains(query) }
    }
}

/// Kur sayfasının iki bölümü.
public struct CatalogSections: Equatable, Sendable {
    public var ready: [CatalogEntry]
    public var upcoming: [CatalogEntry]

    public var isEmpty: Bool { ready.isEmpty && upcoming.isEmpty }
}

/// Arama için metin katlama.
enum SearchText {
    /// Büyük/küçük harf, aksan ve Türkçe ı/i farkını siler: "BAŞLATICISI" → "baslaticisi", "İş" → "is".
    static func fold(_ text: String) -> String {
        let turkish = Locale(identifier: "tr_TR")
        return text.lowercased(with: turkish)
            .folding(options: .diacriticInsensitive, locale: turkish)
            .replacingOccurrences(of: "ı", with: "i")
    }
}
