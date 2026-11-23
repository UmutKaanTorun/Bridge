import Foundation

/// Windows kısayol dosyası (.lnk, MS-SHLLINK) içinden okunan alanlar.
public struct ShellLink: Hashable, Sendable {
    /// LinkInfo'daki yerel yol, ör. "C:\Program Files\Steam\steam.exe".
    public var target: String?
    /// Kısayola ayrıca yazılmış simge dosyası.
    public var iconLocation: String?
    public var iconIndex: Int

    /// Dosya .lnk değilse ya da yarıda kesilmişse nil.
    public init?(data: Data) {
        let bytes = ByteView(data)
        guard bytes.u32(0) == 0x4C, let flags = bytes.u32(0x14), let rawIndex = bytes.u32(0x38) else { return nil }
        let hasIDList = flags & 0x01 != 0, hasLinkInfo = flags & 0x02 != 0, isUnicode = flags & 0x80 != 0
        var offset = 0x4C

        if hasIDList {
            guard let size = bytes.u16(offset) else { return nil }
            offset += 2 + Int(size)
        }

        var target: String?
        if hasLinkInfo {
            guard let size = bytes.u32(offset), size >= 0x1C, let headerSize = bytes.u32(offset + 4),
                  let infoFlags = bytes.u32(offset + 8) else { return nil }
            if infoFlags & 0x01 != 0 {
                if headerSize >= 0x24, let unicodeOffset = bytes.u32(offset + 0x1C), unicodeOffset != 0 {
                    target = Self.utf16CString(bytes, offset + Int(unicodeOffset))
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
            guard let count = bytes.u16(offset) else { return nil }
            let length = Int(count) * (isUnicode ? 2 : 1)
            guard let raw = bytes.bytes(offset + 2, length) else { return nil }
            if isIcon {
                iconLocation = isUnicode ? String(data: raw, encoding: .utf16LittleEndian) : String(data: raw, encoding: .windowsCP1252)
            }
            offset += 2 + length
        }

        self.target = target?.isEmpty == false ? target : nil
        self.iconLocation = iconLocation?.isEmpty == false ? iconLocation : nil
        self.iconIndex = Int(Int32(bitPattern: rawIndex))
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
