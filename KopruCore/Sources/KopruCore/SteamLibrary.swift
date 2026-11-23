import Foundation

/// Bottle'daki Steam'in oyun kütüphaneleri. Steam oyununun kısayolu yalnızca `steam://rungameid/<numara>`
/// taşır; oyunun klasörü Steam'in kayıtlarından (`libraryfolders.vdf`, `appmanifest_<numara>.acf`) bulunur.
public enum SteamLibrary {
    /// Steam'in bottle'da kurulu olabileceği yerler (Steam tarifi 32 bit Program Files'a kurar).
    static let steamFolders = ["C:\\Program Files (x86)\\Steam", "C:\\Program Files\\Steam"]

    /// `steam://rungameid/<numara>` ya da `steam://run/<numara>` bağlantısındaki uygulama numarası.
    public static func appID(fromURL url: String) -> String? {
        let lower = url.lowercased()
        for prefix in ["steam://rungameid/", "steam://run/"] where lower.hasPrefix(prefix) {
            let digits = lower.dropFirst(prefix.count).prefix { $0.isASCII && $0.isNumber }
            return digits.isEmpty ? nil : String(digits)
        }
        return nil
    }

    /// Oyunun kurulu olduğu klasör (`<kütüphane>/steamapps/common/<installdir>`); kaydı ya da klasörü yoksa nil.
    public static func installFolder(appID: String, bottleURL: URL) -> URL? {
        for library in libraries(bottleURL: bottleURL) {
            let steamApps = library.appendingPathComponent("steamapps", isDirectory: true)
            guard let data = try? Data(contentsOf: steamApps.appendingPathComponent("appmanifest_\(appID).acf")),
                  let installDir = ValveKeyValues.values(of: "installdir", in: String(decoding: data, as: UTF8.self)).first,
                  isPlainFolderName(installDir) else { continue }
            let folder = steamApps.appendingPathComponent("common", isDirectory: true)
                .appendingPathComponent(installDir, isDirectory: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return folder
            }
        }
        return nil
    }

    /// Steam'in kendi klasörü ve `libraryfolders.vdf`'teki öteki kütüphaneler; aynı klasör bir kez.
    static func libraries(bottleURL: URL) -> [URL] {
        var result: [URL] = []
        func add(_ url: URL) {
            let standardized = url.standardizedFileURL
            if !result.contains(standardized) { result.append(standardized) }
        }
        for windowsPath in steamFolders {
            guard let steam = WindowsPath.toUnix(windowsPath, bottleURL: bottleURL),
                  FileManager.default.fileExists(atPath: steam.path) else { continue }
            add(steam)
            let file = steam.appendingPathComponent("steamapps/libraryfolders.vdf")
            guard let data = try? Data(contentsOf: file) else { continue }
            for path in ValveKeyValues.values(of: "path", in: String(decoding: data, as: UTF8.self)) {
                if let library = WindowsPath.toUnix(path, bottleURL: bottleURL) { add(library) }
            }
        }
        return result
    }

    /// `installdir` tek bir klasör adı olmalı; ".." ya da bölü işaretiyle kütüphanenin dışına çıkılmaz.
    static func isPlainFolderName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\")
    }
}

/// Valve'ın KeyValues metni (vdf, acf) için en küçük okuyucu: tırnaklı dizgeleri sırayla alır; bir anahtarın
/// değeri ondan sonraki dizgedir. Süslü parantezler ve iç içe yapı yok sayılır; `\\` ters bölüye çevrilir.
enum ValveKeyValues {
    static func values(of key: String, in text: String) -> [String] {
        let tokens = strings(in: text)
        var values: [String] = []
        var index = 0
        while index + 1 < tokens.count {
            if tokens[index].caseInsensitiveCompare(key) == .orderedSame {
                values.append(tokens[index + 1])
                index += 2
            } else {
                index += 1
            }
        }
        return values
    }

    static func strings(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var escaped = false
        for character in text {
            if !inQuotes {
                if character == "\"" { inQuotes = true }
            } else if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                result.append(current)
                current = ""
                inQuotes = false
            } else {
                current.append(character)
            }
        }
        return result
    }
}
