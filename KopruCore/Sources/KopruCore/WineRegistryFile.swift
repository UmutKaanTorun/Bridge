import Foundation

/// Bottle'ın kayıt defteri dosyasını (`user.reg`) Wine başlatmadan okur.
///
/// Wine kayıt defterini wineserver'ın belleğinde tutar, diske arada bir ve kapanırken yazar; dosya geride kalabilir.
/// Bu yüzden yalnız "zaten yazılı mı" sorusu için: yanlış "yok" cevabı gereksiz bir `reg add`'den öteye gitmez.
enum WineRegistryFile {
    /// HKCU altındaki dizge değeri `user.reg`'de tam bu haliyle var mı? Anahtar ve değer adları büyük-küçük harf
    /// ayırmaz, değer ayırır. HKCU dışı kök, okunamayan dosya ve Wine'ın `\x{…}` diye yazdığı karakterler
    /// "bilinmiyor" sayılır (false).
    static func containsUserString(key: String, name: String, value: String, inBottleAt bottleURL: URL) -> Bool {
        guard let path = userRelativePath(key),
              let escapedPath = escape(path, special: "[]"),
              let escapedName = escape(name, special: "\""),
              let escapedValue = escape(value, special: "\""),
              let text = try? String(contentsOf: bottleURL.appendingPathComponent("user.reg"), encoding: .utf8)
        else { return false }

        // Bölüm başlığı: `[Software\\Wine\\…] 1795193701`; değer satırı: `"ad"="değer"`.
        let header = "[\(escapedPath)]".lowercased()
        let namePart = "\"\(escapedName)\"=".lowercased()
        let valuePart = "\"\(escapedValue)\""
        var inKey = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("[") {
                let lower = line.lowercased()
                inKey = lower == header || lower.hasPrefix(header + " ")
            } else if inKey, line.count == namePart.count + valuePart.count,
                      line.prefix(namePart.count).lowercased() == namePart, line.hasSuffix(valuePart) {
                return true
            }
        }
        return false
    }

    /// `HKCU\A\B` → `A\B`; user.reg anahtarları HKCU'ya göre görelidir.
    private static func userRelativePath(_ key: String) -> String? {
        for root in ["HKCU\\", "HKEY_CURRENT_USER\\"] where key.uppercased().hasPrefix(root) {
            return String(key.dropFirst(root.count))
        }
        return nil
    }

    /// Wine'ın yazdığı gibi: `\` ikilenir, `special` karakterler `\` alır. Yazdırılamayan ya da ASCII dışı
    /// karakterde nil (Wine onları `\x{…}` diye yazar; karşılaştırmaya değmez).
    private static func escape(_ string: String, special: String) -> String? {
        var result = ""
        for scalar in string.unicodeScalars {
            guard (0x20...0x7e).contains(scalar.value) else { return nil }
            if scalar == "\\" || special.unicodeScalars.contains(scalar) { result.append("\\") }
            result.unicodeScalars.append(scalar)
        }
        return result
    }
}
