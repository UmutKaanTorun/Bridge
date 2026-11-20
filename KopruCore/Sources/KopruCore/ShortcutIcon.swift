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
        let bytes = ByteView(data)
        guard bytes.u32(0) == 0x4C, let flags = bytes.u32(0x14), let rawIndex = bytes.u32(0x38) else { return [] }
        let hasIDList = flags & 0x01 != 0, hasLinkInfo = flags & 0x02 != 0, isUnicode = flags & 0x80 != 0
        var offset = 0x4C

        if hasIDList {
            guard let size = bytes.u16(offset) else { return [] }
            offset += 2 + Int(size)
        }

        var target: String?
        if hasLinkInfo {
            guard let size = bytes.u32(offset), size >= 0x1C, let headerSize = bytes.u32(offset + 4),
                  let infoFlags = bytes.u32(offset + 8) else { return [] }
            if infoFlags & 0x01 != 0 {
                if headerSize >= 0x24, let unicodeOffset = bytes.u32(offset + 0x1C), unicodeOffset != 0 {
                    target = utf16CString(bytes, offset + Int(unicodeOffset))
                } else if let pathOffset = bytes.u32(offset + 16) {
                    target = bytes.cString(offset + Int(pathOffset))
                }
            }
            offset += Int(size)
        }

        // StringData sırası: ad, göreli yol, çalışma klasörü, argümanlar, simge konumu.
        var iconLocation: String?
        for (bit, isIcon) in [(UInt32(0x04), false), (0x08, false), (0x10, false), (0x20, false), (0x40, true)]
        where flags & bit != 0 {
            guard let count = bytes.u16(offset) else { return [] }
            let length = Int(count) * (isUnicode ? 2 : 1)
            guard let raw = bytes.bytes(offset + 2, length) else { return [] }
            if isIcon {
                iconLocation = isUnicode ? String(data: raw, encoding: .utf16LittleEndian) : String(data: raw, encoding: .windowsCP1252)
            }
            offset += 2 + length
        }

        var result: [IconLocation] = []
        if let iconLocation, !iconLocation.isEmpty {
            result.append(IconLocation(windowsPath: iconLocation, index: Int(Int32(bitPattern: rawIndex))))
        }
        if let target, !target.isEmpty {
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

    private static func utf16CString(_ bytes: ByteView, _ offset: Int) -> String? {
        var units: [UInt16] = []
        var position = offset
        while let unit = bytes.u16(position), unit != 0 {
            units.append(unit)
            position += 2
        }
        return String(decoding: units, as: UTF16.self)
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
