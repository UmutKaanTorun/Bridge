import Foundation
import Testing
@testable import KopruCore

struct ShortcutIconTests {
    /// Wine'ın yazdığı gibi bir .lnk: hedef LinkInfo'daki yerel yol, isteğe bağlı simge konumu.
    private func link(target: String?, iconLocation: String? = nil, iconIndex: Int32 = 0, idList: Bool = true) -> Data {
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

    @Test func linkWithoutIconLocationUsesTarget() {
        let data = link(target: "C:\\Program Files (x86)\\Steam\\steam.exe")
        #expect(ShortcutIcon.candidates(link: data) == [IconLocation(windowsPath: "C:\\Program Files (x86)\\Steam\\steam.exe", index: 0)])
    }

    @Test func linkIconLocationComesBeforeTarget() {
        let data = link(target: "C:\\Oyun\\oyun.exe", iconLocation: "C:\\Oyun\\simge.ico", iconIndex: 2, idList: false)
        #expect(ShortcutIcon.candidates(link: data) == [IconLocation(windowsPath: "C:\\Oyun\\simge.ico", index: 2),
                                                         IconLocation(windowsPath: "C:\\Oyun\\oyun.exe", index: 0)])
    }

    @Test func linkWithOnlyIconLocation() {
        let data = link(target: nil, iconLocation: "C:\\windows\\system32\\shell32.dll", iconIndex: -3)
        #expect(ShortcutIcon.candidates(link: data) == [IconLocation(windowsPath: "C:\\windows\\system32\\shell32.dll", index: -3)])
    }

    @Test func garbageLinkHasNoCandidates() {
        #expect(ShortcutIcon.candidates(link: Data("bozuk".utf8)).isEmpty)
        #expect(ShortcutIcon.candidates(link: Data(link(target: "C:\\a.exe").prefix(0x60))).isEmpty)
    }

    /// Steam oyunu kısayolu.
    @Test func urlIconFile() {
        let text = """
        [InternetShortcut]
        IDList=
        URL=steam://rungameid/2272420
        IconIndex=0
        IconFile=C:\\Program Files (x86)\\Steam\\steam\\games\\abc123.ico
        """
        #expect(ShortcutIcon.candidates(url: text) == [IconLocation(windowsPath: "C:\\Program Files (x86)\\Steam\\steam\\games\\abc123.ico", index: 0)])
        #expect(ShortcutIcon.candidates(url: "[InternetShortcut]\r\nURL=steam://x\r\n").isEmpty)
    }
}
