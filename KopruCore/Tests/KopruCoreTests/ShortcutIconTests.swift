import Foundation
import Testing
@testable import KopruCore

struct ShortcutIconTests {
    @Test func linkWithoutIconLocationUsesTarget() {
        let data = shellLinkData(target: "C:\\Program Files (x86)\\Steam\\steam.exe")
        #expect(ShortcutIcon.candidates(link: data) == [IconLocation(windowsPath: "C:\\Program Files (x86)\\Steam\\steam.exe", index: 0)])
    }

    @Test func linkIconLocationComesBeforeTarget() {
        let data = shellLinkData(target: "C:\\Oyun\\oyun.exe", iconLocation: "C:\\Oyun\\simge.ico", iconIndex: 2, idList: false)
        #expect(ShortcutIcon.candidates(link: data) == [IconLocation(windowsPath: "C:\\Oyun\\simge.ico", index: 2),
                                                         IconLocation(windowsPath: "C:\\Oyun\\oyun.exe", index: 0)])
    }

    @Test func linkWithOnlyIconLocation() {
        let data = shellLinkData(target: nil, iconLocation: "C:\\windows\\system32\\shell32.dll", iconIndex: -3)
        #expect(ShortcutIcon.candidates(link: data) == [IconLocation(windowsPath: "C:\\windows\\system32\\shell32.dll", index: -3)])
    }

    @Test func garbageLinkHasNoCandidates() {
        #expect(ShortcutIcon.candidates(link: Data("bozuk".utf8)).isEmpty)
        #expect(ShortcutIcon.candidates(link: Data(shellLinkData(target: "C:\\a.exe").prefix(0x60))).isEmpty)
    }

    /// Kısayolun hedefi, tarifin başlatıcısıyla aynı programı gösteren kısayolu tanımak için okunur.
    @Test func linkTargetIsLocalBasePath() {
        let data = shellLinkData(target: "C:\\Oyun\\oyun.exe", iconLocation: "C:\\Oyun\\simge.ico", iconIndex: 2)
        #expect(ShellLink(data: data)?.target == "C:\\Oyun\\oyun.exe")
        #expect(ShellLink(data: data)?.iconLocation == "C:\\Oyun\\simge.ico")
        #expect(ShellLink(data: data)?.iconIndex == 2)
        #expect(ShellLink(data: shellLinkData(target: nil, iconLocation: "C:\\x.ico"))?.target == nil)
        #expect(ShellLink(data: Data("bozuk".utf8)) == nil)
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
