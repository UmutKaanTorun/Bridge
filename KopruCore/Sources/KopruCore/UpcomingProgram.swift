import Foundation

/// "Yakında" girdisinin durumu.
public enum UpcomingStatus: String, Codable, Hashable, Sendable {
    case testing, broken

    public var label: String {
        switch self {
        case .testing: "Test ediliyor"
        case .broken: "Şimdilik çalışmıyor"
        }
    }
}

/// Tarifi henüz olmayan, test edilen program (Resources/Catalog/upcoming.json).
public struct UpcomingProgram: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// Emin olunmayan yayıncı yazılmaz.
    public var publisher: String?
    public var summary: String
    public var category: RecipeCategory
    public var status: UpcomingStatus
    /// Çalışmayan programda kullanıcıya gösterilen açıklama.
    public var note: String?

    public init(id: String, name: String, publisher: String? = nil, summary: String,
                category: RecipeCategory, status: UpcomingStatus, note: String? = nil) {
        self.id = id
        self.name = name
        self.publisher = publisher
        self.summary = summary
        self.category = category
        self.status = status
        self.note = note
    }
}
