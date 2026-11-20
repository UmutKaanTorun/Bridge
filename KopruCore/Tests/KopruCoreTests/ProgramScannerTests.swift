import Foundation
import Testing
@testable import KopruCore

struct ProgramScannerTests {
    static let common = "bottle/drive_c/ProgramData/Microsoft/Windows/Start Menu/Programs"
    static let crossover = "bottle/drive_c/users/crossover/AppData/Roaming/Microsoft/Windows/Start Menu/Programs"
    static let umut = "bottle/drive_c/users/umut/AppData/Roaming/Microsoft/Windows/Start Menu/Programs"

    /// Faz 0 bottle'larındaki gerçek kısayollara benzeyen ağaç.
    private func makeTree(_ td: TempDir) throws -> URL {
        try td.file("\(Self.common)/Notepad++.lnk")
        try td.file("\(Self.common)/WinRAR/WinRAR.lnk")
        try td.file("\(Self.common)/WinRAR/WinRAR yardımı.lnk")
        try td.file("\(Self.common)/WinRAR/Konsol RAR kılavuzu.lnk")
        try td.file("\(Self.umut)/WinRAR/WinRAR.lnk")
        try td.file("\(Self.common)/Araç/Uninstall Araç.lnk")
        try td.file("\(Self.crossover)/Steam/Steam.lnk")
        try td.file("\(Self.crossover)/Steam/Thief Simulator 2 Prologue.url",
                    "[InternetShortcut]\r\nIDList=\r\nURL=steam://rungameid/2272420\r\nIconIndex=0\r\n")
        try td.file("\(Self.crossover)/Site.url", "[InternetShortcut]\r\nURL=https://example.com\r\n")
        try td.file("\(Self.crossover)/notlar.txt")
        return td.url.appendingPathComponent("bottle")
    }

    @Test func findsShortcutsAndSteamGames() throws {
        let td = try TempDir()
        let bottle = try makeTree(td)
        let found = ProgramScanner.scan(bottleURL: bottle, hidden: [])
        #expect(found.map(\.name) == ["Notepad++", "Steam", "Thief Simulator 2 Prologue", "WinRAR"])
        #expect(found.map(\.relativePath) == ["Notepad++.lnk", "Steam/Steam.lnk", "Steam/Thief Simulator 2 Prologue.url", "WinRAR/WinRAR.lnk"])
        #expect(found.first { $0.name == "Thief Simulator 2 Prologue" }?.kind == .steamURL("steam://rungameid/2272420"))
        #expect(found.first { $0.name == "Steam" }?.kind == .link)
        #expect(found.first { $0.name == "Notepad++" }?.url.path == bottle.appendingPathComponent(
            "drive_c/ProgramData/Microsoft/Windows/Start Menu/Programs/Notepad++.lnk").path)
    }

    @Test func hiddenShortcutsAreSkipped() throws {
        let td = try TempDir()
        let bottle = try makeTree(td)
        let found = ProgramScanner.scan(bottleURL: bottle, hidden: ["Steam/Steam.lnk", "Notepad++.lnk"])
        #expect(found.map(\.name) == ["Thief Simulator 2 Prologue", "WinRAR"])
    }

    @Test func emptyBottleHasNoPrograms() throws {
        let td = try TempDir()
        #expect(ProgramScanner.scan(bottleURL: try td.dir("bos"), hidden: []).isEmpty)
    }
}
