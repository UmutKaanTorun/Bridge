import Foundation

/// Tarifin uyumluluk notu.
public enum RecipeRating: String, Codable, Hashable, Sendable {
    case works, partial, broken

    public var label: String {
        switch self {
        case .works: "Çalışıyor"
        case .partial: "Kısmen çalışıyor"
        case .broken: "Çalışmıyor"
        }
    }
}

/// Tarifin kurulumdan sonra ya da açılıştan önce uyguladığı eylem.
public enum RecipeAction: Hashable, Sendable {
    /// `wine reg add <key> /v <name> /t REG_SZ /d <value> /f`
    case registry(key: String, name: String, value: String)
    /// Steam'in steamwebhelper.exe dosyasını Köprü'nün aracısıyla değiştirir.
    case steamWebHelperProxy
}

extension RecipeAction: Codable {
    private enum CodingKeys: String, CodingKey { case action, key, name, value }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .action) {
        case "registry":
            self = .registry(key: try c.decode(String.self, forKey: .key),
                             name: try c.decode(String.self, forKey: .name),
                             value: try c.decode(String.self, forKey: .value))
        case "steamWebHelperProxy":
            self = .steamWebHelperProxy
        case let other:
            throw DecodingError.dataCorruptedError(forKey: .action, in: c, debugDescription: "Bilinmeyen tarif eylemi: \(other)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .registry(key, name, value):
            try c.encode("registry", forKey: .action)
            try c.encode(key, forKey: .key)
            try c.encode(name, forKey: .name)
            try c.encode(value, forKey: .value)
        case .steamWebHelperProxy:
            try c.encode("steamWebHelperProxy", forKey: .action)
        }
    }
}

public struct RecipeBottle: Codable, Hashable, Sendable {
    public var defaultName: String
    public var settings: BottleSettings
}

public struct RecipeInstallerSpec: Codable, Hashable, Sendable {
    public var url: URL
    /// Doluysa indirilen dosya doğrulanır; tutmazsa kurulum durur.
    public var sha256: String?
    public var fileName: String
    public var arguments: [String]
}

public struct RecipeLaunch: Codable, Hashable, Sendable {
    public var name: String
    public var windowsPath: String
    public var arguments: [String]
    /// Doluysa "Durdur" önce programı bu argümanlarla çalıştırıp kibarca kapatır.
    public var shutdownArguments: [String]?
}

/// Bir programın tek tık kurulum tarifi (Resources/Recipes/<id>.json).
public struct Recipe: Codable, Hashable, Sendable, Identifiable {
    public var schema: Int
    public var id: String
    public var name: String
    public var summary: String
    public var category: String
    public var rating: RecipeRating
    public var bottle: RecipeBottle
    public var installer: RecipeInstallerSpec
    public var afterInstall: [RecipeAction]
    public var beforeLaunch: [RecipeAction]
    public var launch: RecipeLaunch
    /// İçe aktarılan bottle'da bu dosyaların hepsi varsa bottle bu tarife bağlanır (bottle'a göre göreli).
    public var detect: [String]
    /// Tarifin kendi başlatıcısı varken gizlenen Başlat menüsü kısayolları (Programs'a göre göreli).
    public var hideShortcuts: [String]
}
