import Foundation

/// Görünen bottle adından diskte kullanılacak ASCII klasör adı üretir.
/// Bazı Windows kurulum programları Türkçe karakterli yollarda sorun çıkarabiliyor.
public enum FolderName {
    private static let separators = CharacterSet.whitespaces.union(CharacterSet(charactersIn: "/:\\"))
    private static let extraAllowed = CharacterSet(charactersIn: "-_+.")

    public static func make(from displayName: String, existing: Set<String>) -> String {
        // Noktasız ı ve noktalı İ aksan değil; elle çevrilir. Diğer Türkçe harfler aksan atılarak çevrilir.
        let mapped = displayName.replacingOccurrences(of: "ı", with: "i").replacingOccurrences(of: "İ", with: "I")
        let stripped = mapped.applyingTransform(.stripDiacritics, reverse: false) ?? mapped

        var result = ""
        for scalar in stripped.unicodeScalars {
            if separators.contains(scalar) {
                result += "-"
            } else if scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || extraAllowed.contains(scalar)) {
                result.unicodeScalars.append(scalar)
            }
        }
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        if result.isEmpty { result = "Bottle" }

        // APFS büyük/küçük harf duyarsız: çakışma kontrolü de öyle.
        let taken = Set(existing.map { $0.lowercased() })
        guard taken.contains(result.lowercased()) else { return result }
        var number = 2
        while taken.contains("\(result)-\(number)".lowercased()) { number += 1 }
        return "\(result)-\(number)"
    }
}
