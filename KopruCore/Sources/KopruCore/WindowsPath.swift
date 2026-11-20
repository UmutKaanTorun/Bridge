import Foundation

/// Wine'ın Windows yolları ile Mac yolları arasında çeviri. C: = <bottle>/drive_c, Z: = Mac'in kökü.
public enum WindowsPath {
    public static func toUnix(_ windowsPath: String, bottleURL: URL) -> URL? {
        let normalized = windowsPath.replacingOccurrences(of: "\\", with: "/")
        let characters = Array(normalized)
        guard characters.count >= 2, characters[1] == ":" else { return nil }
        let rest = String(characters.dropFirst(2)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch characters[0].lowercased() {
        case "c":
            let driveC = bottleURL.appendingPathComponent("drive_c", isDirectory: true)
            return rest.isEmpty ? driveC : driveC.appendingPathComponent(rest)
        case "z":
            return URL(fileURLWithPath: "/" + rest)
        default:
            return nil
        }
    }

    public static func fromUnix(_ url: URL, bottleURL: URL) -> String {
        let driveC = bottleURL.appendingPathComponent("drive_c", isDirectory: true).standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path == driveC { return "C:\\" }
        if path.hasPrefix(driveC + "/") {
            return "C:\\" + String(path.dropFirst(driveC.count + 1)).replacingOccurrences(of: "/", with: "\\")
        }
        return "Z:" + path.replacingOccurrences(of: "/", with: "\\")
    }
}
