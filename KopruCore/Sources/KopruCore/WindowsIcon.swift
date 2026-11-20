import Foundation

/// Windows .exe/.dll dosyasındaki simgeyi (RT_GROUP_ICON + RT_ICON kaynakları) .ico verisine çevirir.
/// NSImage .ico'yu doğrudan açar ve boyuta en uygun görüntüyü seçer.
public enum WindowsIcon {
    static let iconType: UInt32 = 3
    static let groupIconType: UInt32 = 14

    /// `index`: Windows'taki IconIndex — 0 ve üstü sıradaki simge grubu, negatifse kaynak kimliği (-index).
    /// Bulunamazsa ilk grup kullanılır.
    public static func icoData(fromExecutable url: URL, index: Int = 0) -> Data? {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return nil }
        return icoData(fromExecutableData: data, index: index)
    }

    public static func icoData(fromExecutableData data: Data, index: Int = 0) -> Data? {
        guard let resources = PEResources(data) else { return nil }
        let groups = resources.resources(ofType: groupIconType)
        guard !groups.isEmpty else { return nil }
        let group: PEResources.Entry
        if index < 0, let match = groups.first(where: { $0.id == UInt32(-index) }) {
            group = match
        } else if index >= 0, index < groups.count {
            group = groups[index]
        } else {
            group = groups[0]
        }
        guard let directory = resources.data(of: group) else { return nil }
        let header = ByteView(directory)
        guard header.u16(0) == 0, header.u16(2) == 1, let count = header.u16(4) else { return nil }

        let icons = resources.resources(ofType: iconType)
        var images: [(entry: Data, image: Data)] = []
        for i in 0 ..< Int(count) {
            let offset = 6 + 14 * i
            // GRPICONDIRENTRY: genişlik, yükseklik, renk, ayrılmış, düzlem, bit, boyut (12 bayt) + kaynak kimliği
            guard let entry = header.bytes(offset, 12), let id = header.u16(offset + 12) else { break }
            guard let icon = icons.first(where: { $0.id == UInt32(id) }),
                  let image = resources.data(of: icon), !image.isEmpty else { continue }
            images.append((entry, image))
        }
        guard !images.isEmpty else { return nil }

        var ico = littleEndian(UInt16(0)) + littleEndian(UInt16(1)) + littleEndian(UInt16(images.count))
        var imageOffset = 6 + 16 * images.count
        for (entry, image) in images {
            ico += entry.prefix(8) + littleEndian(UInt32(image.count)) + littleEndian(UInt32(imageOffset))
            imageOffset += image.count
        }
        for (_, image) in images { ico += image }
        return ico
    }

    private static func littleEndian(_ value: UInt16) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
    private static func littleEndian(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
}

/// PE dosyasının kaynak (.rsrc) ağacı: tür → kaynak → dil → veri.
struct PEResources {
    struct Entry {
        /// Sayısal kimlik; adla tanımlı kaynaklarda nil.
        let id: UInt32?
        /// Kaynak köküne göre konum; üst bit alt dizin demek.
        let offset: UInt32
        var isDirectory: Bool { offset & 0x8000_0000 != 0 }
    }

    private struct Section {
        let virtualAddress: UInt32
        let virtualSize: UInt32
        let rawPointer: UInt32
        let rawSize: UInt32
    }

    private let bytes: ByteView
    private let sections: [Section]
    private var root = 0

    init?(_ data: Data) {
        let bytes = ByteView(data)
        guard bytes.u16(0) == 0x5A4D, let peOffset = bytes.u32(0x3C).map(Int.init),
              bytes.u32(peOffset) == 0x0000_4550 else { return nil }
        let coff = peOffset + 4
        guard let sectionCount = bytes.u16(coff + 2), let optionalSize = bytes.u16(coff + 16) else { return nil }
        let optional = coff + 20
        let directories: Int, directoryCountOffset: Int
        switch bytes.u16(optional) {
        case 0x10B: (directories, directoryCountOffset) = (optional + 96, optional + 92)
        case 0x20B: (directories, directoryCountOffset) = (optional + 112, optional + 108)
        default: return nil
        }
        guard let directoryCount = bytes.u32(directoryCountOffset), directoryCount > 2,
              let resourceRVA = bytes.u32(directories + 16), let resourceSize = bytes.u32(directories + 20),
              resourceRVA != 0, resourceSize != 0 else { return nil }

        var sections: [Section] = []
        let table = optional + Int(optionalSize)
        for i in 0 ..< Int(sectionCount) {
            let header = table + 40 * i
            guard let virtualSize = bytes.u32(header + 8), let virtualAddress = bytes.u32(header + 12),
                  let rawSize = bytes.u32(header + 16), let rawPointer = bytes.u32(header + 20) else { return nil }
            sections.append(Section(virtualAddress: virtualAddress, virtualSize: virtualSize,
                                    rawPointer: rawPointer, rawSize: rawSize))
        }
        self.bytes = bytes
        self.sections = sections
        guard let root = fileOffset(ofRVA: resourceRVA) else { return nil }
        self.root = root
    }

    /// Bir türün (ör. 14 = RT_GROUP_ICON) kaynakları, dosyadaki sırayla.
    func resources(ofType type: UInt32) -> [Entry] {
        guard let typeEntry = entries(inDirectory: 0).first(where: { $0.id == type }), typeEntry.isDirectory else { return [] }
        return entries(inDirectory: typeEntry.offset).filter(\.isDirectory)
    }

    /// Kaynağın ilk dil sürümünün verisi.
    func data(of resource: Entry) -> Data? {
        guard resource.isDirectory, let language = entries(inDirectory: resource.offset).first,
              !language.isDirectory else { return nil }
        let dataEntry = root + Int(language.offset)
        guard let rva = bytes.u32(dataEntry), let size = bytes.u32(dataEntry + 4),
              let offset = fileOffset(ofRVA: rva) else { return nil }
        return bytes.bytes(offset, Int(size))
    }

    private func entries(inDirectory offset: UInt32) -> [Entry] {
        let directory = root + Int(offset & 0x7FFF_FFFF)
        guard let named = bytes.u16(directory + 12), let numbered = bytes.u16(directory + 14) else { return [] }
        var result: [Entry] = []
        for i in 0 ..< Int(named) + Int(numbered) {
            let entry = directory + 16 + 8 * i
            guard let name = bytes.u32(entry), let target = bytes.u32(entry + 4) else { break }
            result.append(Entry(id: name & 0x8000_0000 == 0 ? name : nil, offset: target))
        }
        return result
    }

    private func fileOffset(ofRVA rva: UInt32) -> Int? {
        for section in sections where rva >= section.virtualAddress {
            let delta = rva - section.virtualAddress
            guard delta < max(section.virtualSize, section.rawSize) else { continue }
            guard delta < section.rawSize else { return nil }
            return Int(section.rawPointer) + Int(delta)
        }
        return nil
    }
}

/// Sınır denetimli küçük-uçlu (little-endian) okuma.
struct ByteView {
    let data: Data

    init(_ data: Data) { self.data = data }

    func u8(_ offset: Int) -> UInt8? {
        guard offset >= 0, offset < data.count else { return nil }
        return data[data.startIndex + offset]
    }

    func u16(_ offset: Int) -> UInt16? {
        guard let low = u8(offset), let high = u8(offset + 1) else { return nil }
        return UInt16(low) | UInt16(high) << 8
    }

    func u32(_ offset: Int) -> UInt32? {
        guard let low = u16(offset), let high = u16(offset + 2) else { return nil }
        return UInt32(low) | UInt32(high) << 16
    }

    func bytes(_ offset: Int, _ count: Int) -> Data? {
        guard offset >= 0, count >= 0, offset <= data.count - count else { return nil }
        let start = data.startIndex + offset
        return data.subdata(in: start ..< start + count)
    }

    /// `offset`'ten sıfır baytına kadar olan dizgi (UTF-8, olmazsa Windows-1252).
    func cString(_ offset: Int) -> String? {
        guard offset >= 0, offset < data.count else { return nil }
        let start = data.startIndex + offset
        let end = data[start...].firstIndex(of: 0) ?? data.endIndex
        let raw = data.subdata(in: start ..< end)
        return String(data: raw, encoding: .utf8) ?? String(data: raw, encoding: .windowsCP1252)
    }
}
