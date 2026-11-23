import Foundation

/// Başlat menüsünde bulunan program kısayolu.
public struct ShortcutProgram: Hashable, Sendable, Identifiable {
    public enum Kind: Hashable, Sendable {
        /// .lnk kısayolu
        case link
        /// URL=steam://… içeren .url kısayolu (Steam oyunu)
        case steamURL(String)
    }

    public let name: String
    /// Programs klasörüne göre göreli yol, ör. "Steam/Steam.lnk".
    public let relativePath: String
    public let url: URL
    public let kind: Kind
    /// .lnk'nin gösterdiği program (Windows yolu); okunamadıysa ya da .url ise nil.
    public let target: String?

    public init(name: String, relativePath: String, url: URL, kind: Kind, target: String? = nil) {
        self.name = name
        self.relativePath = relativePath
        self.url = url
        self.kind = kind
        self.target = target
    }

    public var id: String { relativePath }
}

/// Bottle'ın Başlat menüsündeki kısayolları tarar.
public enum ProgramScanner {
    static let programsSubpath = "Microsoft/Windows/Start Menu/Programs"
    /// Adında bunlar geçen kısayollar program değil (kaldırıcı, belge).
    static let excludedWords = ["uninstall", "kaldır", "readme", "benioku", "yardım", "help", "kılavuz", "manual"]

    /// Ortak Başlat menüsü + her Wine kullanıcısının Başlat menüsü (CrossOver motorunda kullanıcı "crossover").
    public static func roots(bottleURL: URL) -> [URL] {
        let driveC = bottleURL.appendingPathComponent("drive_c", isDirectory: true)
        var roots = [driveC.appendingPathComponent("ProgramData").appendingPathComponent(programsSubpath)]
        let users = driveC.appendingPathComponent("users", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: users.path)) ?? []
        for name in names.sorted() {
            roots.append(users.appendingPathComponent(name).appendingPathComponent("AppData/Roaming").appendingPathComponent(programsSubpath))
        }
        return roots
    }

    /// Kısayollar ada göre sıralı; aynı göreli yol bir kez alınır.
    public static func scan(bottleURL: URL, hidden: Set<String>) -> [ShortcutProgram] {
        var seen = Set<String>()
        var result: [ShortcutProgram] = []
        for root in roots(bottleURL: bottleURL) {
            guard let enumerator = FileManager.default.enumerator(atPath: root.path) else { continue }
            while let relative = enumerator.nextObject() as? String {
                let ext = (relative as NSString).pathExtension.lowercased()
                guard ext == "lnk" || ext == "url", !seen.contains(relative), !hidden.contains(relative) else { continue }
                let name = ((relative as NSString).lastPathComponent as NSString).deletingPathExtension
                if excludedWords.contains(where: { name.localizedCaseInsensitiveContains($0) }) { continue }
                let url = root.appendingPathComponent(relative)
                let kind: ShortcutProgram.Kind
                var target: String?
                if ext == "url" {
                    guard let steam = steamURL(in: url) else { continue }
                    kind = .steamURL(steam)
                } else {
                    kind = .link
                    target = (try? Data(contentsOf: url)).flatMap { ShellLink(data: $0) }?.target
                }
                seen.insert(relative)
                result.append(ShortcutProgram(name: name, relativePath: relative, url: url, kind: kind, target: target))
            }
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// .url dosyasındaki "URL=steam://…" değeri; Steam dışı bağlantılar için nil.
    static func steamURL(in file: URL) -> String? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        for line in String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.lowercased().hasPrefix("url=") else { continue }
            let value = String(trimmed.dropFirst(4))
            return value.lowercased().hasPrefix("steam://") ? value : nil
        }
        return nil
    }
}
