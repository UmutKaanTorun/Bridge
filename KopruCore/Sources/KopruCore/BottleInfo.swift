import Foundation

/// Kullanıcının "Program Çalıştır…" ile seçip listeye sabitlediği exe.
public struct PinnedProgram: Codable, Hashable, Sendable {
    public var name: String
    /// Wine'ın gördüğü yol, ör. C:\Program Files\Araç\arac.exe
    public var windowsPath: String
    public var arguments: [String]

    public init(name: String, windowsPath: String, arguments: [String] = []) {
        self.name = name
        self.windowsPath = windowsPath
        self.arguments = arguments
    }
}

/// Bottle klasöründeki kopru.json: Köprü'ye ait bottle bilgisi.
public struct BottleInfo: Codable, Hashable, Sendable {
    public static let fileName = "kopru.json"

    public var schema: Int
    /// Görünen ad (Türkçe karakter içerebilir).
    public var name: String
    public var createdAt: Date
    public var recipeId: String?
    public var settings: BottleSettings
    public var pinnedPrograms: [PinnedProgram]
    /// "Listeden kaldır" denen kısayollar; Programs klasörüne göre göreli yol (ör. "Steam/Steam.lnk").
    public var hiddenShortcuts: [String]

    public init(name: String,
                createdAt: Date,
                recipeId: String? = nil,
                settings: BottleSettings = .default,
                pinnedPrograms: [PinnedProgram] = [],
                hiddenShortcuts: [String] = []) {
        self.schema = 1
        self.name = name
        self.createdAt = createdAt
        self.recipeId = recipeId
        self.settings = settings
        self.pinnedPrograms = pinnedPrograms
        self.hiddenShortcuts = hiddenShortcuts
    }

    public static func read(from bottleURL: URL) throws -> BottleInfo {
        let data = try Data(contentsOf: bottleURL.appendingPathComponent(fileName))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BottleInfo.self, from: data)
    }

    public func write(to bottleURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: bottleURL.appendingPathComponent(Self.fileName), options: .atomic)
    }
}
