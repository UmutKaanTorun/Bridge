import Foundation

/// Testler için içinde simge kaynakları (RT_ICON + RT_GROUP_ICON) olan küçük bir PE dosyası üretir.
enum PEBuilder {
    struct Icon {
        let id: UInt16
        let width: UInt8
        let image: Data
    }

    struct Group {
        let id: UInt32
        let icons: [Icon]
    }

    static let resourceRVA: UInt32 = 0x2000

    static func make(groups: [Group], pe32Plus: Bool = true) -> Data {
        let iconItems = groups.flatMap { group in group.icons.map { (id: UInt32($0.id), data: $0.image) } }
        let groupItems = groups.map { group -> (id: UInt32, data: Data) in
            var directory = le16(0) + le16(1) + le16(UInt16(group.icons.count))
            for icon in group.icons {
                directory += Data([icon.width, icon.width, 0, 0]) + le16(1) + le16(32)
                    + le32(UInt32(icon.image.count)) + le16(icon.id)
            }
            return (group.id, directory)
        }
        let resources = resourceSection(types: [(3, iconItems), (14, groupItems)])

        let optionalSize = pe32Plus ? 240 : 224
        let rawPointer = 0x400
        var file = Data(count: rawPointer + resources.count)
        put16(&file, 0x5A4D, at: 0)
        put32(&file, 0x40, at: 0x3C)
        put32(&file, 0x0000_4550, at: 0x40)
        let coff = 0x44
        put16(&file, pe32Plus ? 0x8664 : 0x14C, at: coff)
        put16(&file, 2, at: coff + 2)
        put16(&file, UInt16(optionalSize), at: coff + 16)
        let optional = coff + 20
        put16(&file, pe32Plus ? 0x20B : 0x10B, at: optional)
        put32(&file, 16, at: optional + (pe32Plus ? 108 : 92))
        let directories = optional + (pe32Plus ? 112 : 96)
        put32(&file, resourceRVA, at: directories + 16)
        put32(&file, UInt32(resources.count), at: directories + 20)
        // Bölüm 0: boş .text (adres eşlemesinin doğru bölümü seçtiğini sınar), bölüm 1: .rsrc
        let sections = optional + optionalSize
        put32(&file, 0x100, at: sections + 8)
        put32(&file, 0x1000, at: sections + 12)
        put32(&file, UInt32(resources.count), at: sections + 40 + 8)
        put32(&file, resourceRVA, at: sections + 40 + 12)
        put32(&file, UInt32(resources.count), at: sections + 40 + 16)
        put32(&file, UInt32(rawPointer), at: sections + 40 + 20)
        file.replaceSubrange(rawPointer ..< rawPointer + resources.count, with: resources)
        return file
    }

    /// Kök → tür → kaynak → dil dizinleri, veri girişleri ve ham veri.
    private static func resourceSection(types: [(type: UInt32, items: [(id: UInt32, data: Data)])]) -> Data {
        var cursor = 16 + 8 * types.count
        var typeDirectories: [Int] = []
        for type in types {
            typeDirectories.append(cursor)
            cursor += 16 + 8 * type.items.count
        }
        var languageDirectories: [[Int]] = []
        for type in types {
            languageDirectories.append(type.items.map { _ in defer { cursor += 24 }; return cursor })
        }
        var dataEntries: [[Int]] = []
        for type in types {
            dataEntries.append(type.items.map { _ in defer { cursor += 16 }; return cursor })
        }
        var rawData: [[Int]] = []
        for type in types {
            rawData.append(type.items.map { item in
                defer { cursor = (cursor + item.data.count + 3) & ~3 }
                return cursor
            })
        }

        var out = Data(count: cursor)
        put16(&out, UInt16(types.count), at: 14)
        for (i, type) in types.enumerated() {
            put32(&out, type.type, at: 16 + 8 * i)
            put32(&out, UInt32(typeDirectories[i]) | 0x8000_0000, at: 16 + 8 * i + 4)
            let directory = typeDirectories[i]
            put16(&out, UInt16(type.items.count), at: directory + 14)
            for (j, item) in type.items.enumerated() {
                put32(&out, item.id, at: directory + 16 + 8 * j)
                put32(&out, UInt32(languageDirectories[i][j]) | 0x8000_0000, at: directory + 16 + 8 * j + 4)
                let language = languageDirectories[i][j]
                put16(&out, 1, at: language + 14)
                put32(&out, 0x409, at: language + 16)
                put32(&out, UInt32(dataEntries[i][j]), at: language + 20)
                let entry = dataEntries[i][j]
                put32(&out, resourceRVA + UInt32(rawData[i][j]), at: entry)
                put32(&out, UInt32(item.data.count), at: entry + 4)
                out.replaceSubrange(rawData[i][j] ..< rawData[i][j] + item.data.count, with: item.data)
            }
        }
        return out
    }
}

func le16(_ value: UInt16) -> Data { Data([UInt8(value & 0xFF), UInt8(value >> 8)]) }
func le32(_ value: UInt32) -> Data { le16(UInt16(value & 0xFFFF)) + le16(UInt16(value >> 16)) }

func put16(_ data: inout Data, _ value: UInt16, at offset: Int) {
    data.replaceSubrange(offset ..< offset + 2, with: le16(value))
}

func put32(_ data: inout Data, _ value: UInt32, at offset: Int) {
    data.replaceSubrange(offset ..< offset + 4, with: le32(value))
}

/// .ico verisinin girişleri: (genişlik, görüntü verisi).
func icoEntries(_ ico: Data) -> [(width: UInt8, image: Data)]? {
    let bytes = [UInt8](ico)
    guard bytes.count >= 6, bytes[0] == 0, bytes[1] == 0, bytes[2] == 1, bytes[3] == 0 else { return nil }
    let count = Int(bytes[4]) | Int(bytes[5]) << 8
    var result: [(UInt8, Data)] = []
    for i in 0 ..< count {
        let entry = 6 + 16 * i
        guard entry + 16 <= bytes.count else { return nil }
        func u32(_ o: Int) -> Int { Int(bytes[o]) | Int(bytes[o + 1]) << 8 | Int(bytes[o + 2]) << 16 | Int(bytes[o + 3]) << 24 }
        let size = u32(entry + 8), offset = u32(entry + 12)
        guard offset + size <= bytes.count else { return nil }
        result.append((bytes[entry], Data(bytes[offset ..< offset + size])))
    }
    return result
}
