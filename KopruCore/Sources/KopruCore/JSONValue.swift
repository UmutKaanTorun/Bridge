import Foundation

/// Tarifte serbest biçimli JSON değeri (ör. `jsonValues` eyleminin yazdığı değerler).
public indirect enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let value = try? c.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? c.decode(Double.self) {
            self = .number(value)
        } else if let value = try? c.decode(String.self) {
            self = .string(value)
        } else if let value = try? c.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try c.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case let .string(value): try c.encode(value)
        case let .number(value): try c.encode(value)
        case let .bool(value): try c.encode(value)
        case .null: try c.encodeNil()
        case let .array(value): try c.encode(value)
        case let .object(value): try c.encode(value)
        }
    }

    /// `JSONSerialization`'ın yazabileceği karşılığı.
    var foundationObject: Any {
        switch self {
        case let .string(value): value
        case let .number(value):
            if value.rounded() == value, let integer = Int(exactly: value) { integer } else { value }
        case let .bool(value): value
        case .null: NSNull()
        case let .array(value): value.map(\.foundationObject)
        case let .object(value): value.mapValues(\.foundationObject)
        }
    }
}

/// Bottle içindeki bir JSON dosyasının üst düzey anahtarlarına değer yazar; öteki anahtarlara dokunmaz.
/// GOG Galaxy gibi programlar ayarlarını kendi config.json'larında tutar ve o dosyayı kendileri de yazar.
enum JSONFileValues {
    /// Bottle'a göre göreli yolu çözer. Mutlak yol, `..` ya da bottle dışına çıkan yol reddedilir:
    /// tarifler depodan da gelebilir.
    static func resolve(_ relative: String, inBottleAt bottleURL: URL) throws -> URL {
        let components = relative.split(separator: "/", omittingEmptySubsequences: false)
        guard !relative.isEmpty, !relative.hasPrefix("/"), !components.contains("..") else {
            throw RecipeActionError.unsafePath(relative)
        }
        // Yol standartlaşmış kökten türetilir: var olan kök standartlaşırken `/private`'ı kaybedebiliyor
        // (/private/tmp → /tmp), henüz var olmayan dosya kaybetmiyor; ikisi ayrı standartlaşınca önek tutmuyordu.
        let rootURL = bottleURL.standardizedFileURL
        let root = rootURL.path
        let url = rootURL.appendingPathComponent(relative).standardizedFileURL
        guard url.path.hasPrefix(root + "/") else { throw RecipeActionError.unsafePath(relative) }
        return url
    }

    static func apply(_ values: [String: JSONValue], toFile relative: String, inBottleAt bottleURL: URL) throws {
        let url = try resolve(relative, inBottleAt: bottleURL)
        var object: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           !String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                throw RecipeActionError.invalidJSONFile(url.path)
            }
            object = parsed
        }
        for (key, value) in values {
            object[key] = value.foundationObject
        }
        let data = try JSONSerialization.data(withJSONObject: object,
                                              options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
