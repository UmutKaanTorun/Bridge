import Foundation

/// Tarifin uyumluluk notu.
public enum RecipeRating: String, Codable, Hashable, Sendable {
    case perfect, works, partial, broken

    public var label: String {
        switch self {
        case .perfect: "Sorunsuz"
        case .works: "Çalışıyor"
        case .partial: "Kısmen çalışıyor"
        case .broken: "Şimdilik çalışmıyor"
        }
    }
}

/// Kur sayfasındaki kategori.
public enum RecipeCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case game, business, engineering, office

    public var label: String {
        switch self {
        case .game: "Oyun"
        case .business: "İş ve muhasebe"
        case .engineering: "Mühendislik"
        case .office: "Ofis"
        }
    }

    /// Simgesi olmayan programın yerine gösterilen SF Symbol.
    public var symbolName: String {
        switch self {
        case .game: "gamecontroller"
        case .business: "building.columns"
        case .engineering: "ruler"
        case .office: "doc.text"
        }
    }
}

/// Tarifin son test edildiği ortam.
public struct RecipeTestInfo: Codable, Hashable, Sendable {
    /// "yyyy-MM-dd"
    public var date: String
    public var hardware: String
    public var macOS: String

    public init(date: String, hardware: String, macOS: String) {
        self.date = date
        self.hardware = hardware
        self.macOS = macOS
    }

    /// "20 Kas 2026 · Apple M3 · macOS 26.6"; tarih okunamazsa olduğu gibi yazılır.
    public var summary: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd"
        var day = date
        if let parsed = parser.date(from: date) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "d MMM yyyy"
            day = formatter.string(from: parsed)
        }
        return "\(day) · \(hardware) · macOS \(macOS)"
    }
}

/// Panelde "Köprü senin yerine ayarlar" altında bir madde. Tarifte gerçekten yapılan bir şeye karşılık gelmeli.
public struct RecipeHighlight: Codable, Hashable, Sendable {
    public var title: String
    public var detail: String

    public init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }
}

/// Tarifin kurulumdan sonra ya da açılıştan önce uyguladığı eylem.
public enum RecipeAction: Hashable, Sendable {
    /// `wine reg add <key> /v <name> /t REG_SZ /d <value> /f`
    case registry(key: String, name: String, value: String)
    /// Steam'in steamwebhelper.exe dosyasını Köprü'nün aracısıyla değiştirir.
    case steamWebHelperProxy

    /// Yalnızca dosyalara dokunan, Wine çalıştırmayan eylemler; bottle çalışırken sık sık tekrarlanabilir.
    public var isFileAction: Bool {
        switch self {
        case .registry: false
        case .steamWebHelperProxy: true
        }
    }
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
    /// Bottle'a göre göreli dosya; yoksa program henüz ilk kurulumunu bitirmemiş sayılır
    /// ve `firstRunArguments` ile açılır (ör. Steam istemcisi SteamUI.dll ilk açılışta indirilir).
    public var readyFile: String?
    public var firstRunArguments: [String]?

    /// `readyFile` henüz yoksa ilk açılış argümanları, varsa normal argümanlar.
    public func arguments(forBottleAt bottleURL: URL) -> [String] {
        guard let readyFile, let firstRunArguments,
              !FileManager.default.fileExists(atPath: bottleURL.appendingPathComponent(readyFile).path) else {
            return arguments
        }
        return firstRunArguments
    }
}

/// Bir programın tek tık kurulum tarifi (Resources/Recipes/<id>.json).
public struct Recipe: Codable, Hashable, Sendable, Identifiable {
    public var schema: Int
    public var id: String
    public var name: String
    public var summary: String
    public var category: RecipeCategory
    public var rating: RecipeRating
    public var bottle: RecipeBottle
    public var installer: RecipeInstallerSpec
    public var afterInstall: [RecipeAction]
    public var beforeLaunch: [RecipeAction]
    /// Bottle çalıştığı sürece saniyede bir yeniden uygulanan dosya eylemleri. Steam ilk açılışta ve her
    /// güncellemede tarayıcı dosyalarını açılıştan sonra yeniden yazdığı için aracı ancak böyle yerinde kalır.
    public var whileRunning: [RecipeAction]?
    public var launch: RecipeLaunch
    /// İçe aktarılan bottle'da bu dosyaların hepsi varsa bottle bu tarife bağlanır (bottle'a göre göreli).
    public var detect: [String]
    /// Tarifin kendi başlatıcısı varken gizlenen Başlat menüsü kısayolları (Programs'a göre göreli).
    public var hideShortcuts: [String]
    // Kur sayfası alanları; hepsi isteğe bağlı, eski tarifler bunlarsız da çözülür.
    public var publisher: String?
    /// Neyin çalışıp neyin çalışmadığını anlatan cümle.
    public var verdict: String?
    public var testedOn: RecipeTestInfo?
    /// Ör. "2 MB, ilk açılışta …"
    public var downloadNote: String?
    public var highlights: [RecipeHighlight]?
}
