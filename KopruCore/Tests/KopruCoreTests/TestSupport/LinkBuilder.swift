import Foundation

/// Wine'ın yazdığı gibi bir .lnk: hedef LinkInfo'daki yerel yol, isteğe bağlı simge konumu.
func shellLinkData(target: String?, iconLocation: String? = nil, iconIndex: Int32 = 0, idList: Bool = true) -> Data {
    var flags: UInt32 = 0x80 // IsUnicode
    if idList { flags |= 0x01 }
    if target != nil { flags |= 0x02 }
    if iconLocation != nil { flags |= 0x40 }
    flags |= 0x10 // HasWorkingDir: simge konumundan önce gelen dizgilerin atlandığını sınar

    var data = Data(count: 0x4C)
    put32(&data, 0x4C, at: 0)
    put32(&data, flags, at: 0x14)
    put32(&data, UInt32(bitPattern: iconIndex), at: 0x38)
    if idList {
        let items = Data(repeating: 0x11, count: 20)
        data += le16(UInt16(items.count)) + items
    }
    if let target {
        let path = Data(target.utf8) + Data([0])
        let headerSize = 0x1C, volumeID = Data(repeating: 0, count: 0x10)
        let localBasePathOffset = headerSize + volumeID.count
        let size = localBasePathOffset + path.count + 1
        var info = Data(count: headerSize)
        put32(&info, UInt32(size), at: 0)
        put32(&info, UInt32(headerSize), at: 4)
        put32(&info, 1, at: 8) // VolumeIDAndLocalBasePath
        put32(&info, UInt32(headerSize), at: 12)
        put32(&info, UInt32(localBasePathOffset), at: 16)
        put32(&info, UInt32(size - 1), at: 24) // CommonPathSuffix: boş dizgi
        data += info + volumeID + path + Data([0])
    }
    func unicodeString(_ text: String) -> Data {
        let units = Array(text.utf16)
        return units.reduce(le16(UInt16(units.count))) { $0 + le16($1) }
    }
    data += unicodeString("C:\\Program Files (x86)\\Steam")
    if let iconLocation { data += unicodeString(iconLocation) }
    return data + le32(0)
}
