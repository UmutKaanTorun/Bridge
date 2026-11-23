import Foundation

/// Simgenin bulunduğu dosya ve sırası (Windows'taki IconLocation + IconIndex).
public struct IconLocation: Hashable, Sendable {
    public var windowsPath: String
    public var index: Int

    public init(windowsPath: String, index: Int) {
        self.windowsPath = windowsPath
        self.index = index
    }
}

/// Kısayol dosyalarının (.lnk, .url) simgesinin nerede olduğu.
public enum ShortcutIcon {
    /// .lnk (MS-SHLLINK): önce kısayola yazılmış simge konumu, sonra hedef program.
    public static func candidates(link data: Data) -> [IconLocation] {
        guard let link = ShellLink(data: data) else { return [] }
        var result: [IconLocation] = []
        if let iconLocation = link.iconLocation {
            result.append(IconLocation(windowsPath: iconLocation, index: link.iconIndex))
        }
        if let target = link.target {
            result.append(IconLocation(windowsPath: target, index: 0))
        }
        return result
    }

    /// .url (Internet kısayolu, ör. Steam oyunu): IconFile= ve IconIndex=.
    public static func candidates(url text: String) -> [IconLocation] {
        var file: String?
        var index = 0
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            switch parts[0].lowercased() {
            case "iconfile": file = parts[1]
            case "iconindex": index = Int(parts[1]) ?? 0
            default: break
            }
        }
        guard let file, !file.isEmpty else { return [] }
        return [IconLocation(windowsPath: file, index: index)]
    }
}

/// Program ızgarasındaki kutucuğun simgesi.
public enum ProgramIcon {
    /// Simgenin aranacağı yerler, öncelik sırasıyla.
    public static func candidates(for item: ProgramItem) -> [IconLocation] {
        switch item.source {
        case let .recipe(launch):
            return [IconLocation(windowsPath: launch.windowsPath, index: 0)]
        case let .pinned(program):
            return [IconLocation(windowsPath: program.windowsPath, index: 0)]
        case let .epicGame(game):
            return [IconLocation(windowsPath: game.executable, index: 0)]
        case let .shortcut(shortcut):
            guard let data = try? Data(contentsOf: shortcut.url) else { return [] }
            switch shortcut.kind {
            case .link: return ShortcutIcon.candidates(link: data)
            case .steamURL: return ShortcutIcon.candidates(url: String(decoding: data, as: UTF8.self))
            }
        }
    }

    /// .ico dosyası olduğu gibi, .exe/.dll içinden çıkarılan simge .ico olarak. Bulunamazsa nil.
    public static func icoData(for item: ProgramItem, bottleURL: URL) -> Data? {
        for location in candidates(for: item) {
            guard let file = WindowsPath.toUnix(location.windowsPath, bottleURL: bottleURL) else { continue }
            if file.pathExtension.lowercased() == "ico" {
                if let data = try? Data(contentsOf: file), data.prefix(4) == Data([0, 0, 1, 0]) { return data }
            } else if let data = WindowsIcon.icoData(fromExecutable: file, index: location.index) {
                return data
            }
        }
        return nil
    }
}
