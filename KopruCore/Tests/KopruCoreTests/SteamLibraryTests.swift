import Foundation
import Testing
@testable import KopruCore

struct SteamLibraryTests {
    static let steamApps = "bottle/drive_c/Program Files (x86)/Steam/steamapps"

    private func manifest(appID: String, installDir: String) -> String {
        """
        "AppState"
        {
        \t"appid"\t\t"\(appID)"
        \t"name"\t\t"Thief Simulator 2: Prologue"
        \t"installdir"\t\t"\(installDir)"
        \t"UserConfig"
        \t{
        \t\t"language"\t\t"english"
        \t}
        }
        """
    }

    @Test func appIDFromSteamURL() {
        #expect(SteamLibrary.appID(fromURL: "steam://rungameid/2272420") == "2272420")
        #expect(SteamLibrary.appID(fromURL: "steam://run/570") == "570")
        #expect(SteamLibrary.appID(fromURL: "STEAM://RunGameID/570/") == "570")
        #expect(SteamLibrary.appID(fromURL: "steam://open/games") == nil)
        #expect(SteamLibrary.appID(fromURL: "steam://rungameid/") == nil)
        #expect(SteamLibrary.appID(fromURL: "https://store.steampowered.com/app/570") == nil)
    }

    @Test func gameInSteamsOwnLibrary() throws {
        let td = try TempDir()
        try td.file("\(Self.steamApps)/appmanifest_2272420.acf", manifest(appID: "2272420", installDir: "Thief Simulator 2 Prologue"))
        let game = try td.dir("\(Self.steamApps)/common/Thief Simulator 2 Prologue")
        let found = SteamLibrary.installFolder(appID: "2272420", bottleURL: td.url.appendingPathComponent("bottle"))
        #expect(found?.standardizedFileURL == game.standardizedFileURL)
    }

    /// Ek kütüphaneler libraryfolders.vdf'te; yollardaki ters bölüler kaçışlı yazılır.
    @Test func gameInAnotherLibrary() throws {
        let td = try TempDir()
        try td.file("\(Self.steamApps)/libraryfolders.vdf", """
        "libraryfolders"
        {
        \t"0"
        \t{
        \t\t"path"\t\t"C:\\\\Program Files (x86)\\\\Steam"
        \t\t"apps"
        \t\t{
        \t\t}
        \t}
        \t"1"
        \t{
        \t\t"path"\t\t"C:\\\\Oyunlar\\\\SteamLibrary"
        \t\t"apps"
        \t\t{
        \t\t\t"730"\t\t"123"
        \t\t}
        \t}
        }
        """)
        try td.file("bottle/drive_c/Oyunlar/SteamLibrary/steamapps/appmanifest_730.acf", manifest(appID: "730", installDir: "Counter-Strike Global Offensive"))
        let game = try td.dir("bottle/drive_c/Oyunlar/SteamLibrary/steamapps/common/Counter-Strike Global Offensive")
        let found = SteamLibrary.installFolder(appID: "730", bottleURL: td.url.appendingPathComponent("bottle"))
        #expect(found?.standardizedFileURL == game.standardizedFileURL)
    }

    @Test func missingManifestOrFolderGivesNil() throws {
        let td = try TempDir()
        let bottle = td.url.appendingPathComponent("bottle")
        try td.file("\(Self.steamApps)/appmanifest_1.acf", manifest(appID: "1", installDir: "Silinmis"))
        try td.file("\(Self.steamApps)/appmanifest_2.acf", "bozuk")
        #expect(SteamLibrary.installFolder(appID: "1", bottleURL: bottle) == nil)
        #expect(SteamLibrary.installFolder(appID: "2", bottleURL: bottle) == nil)
        #expect(SteamLibrary.installFolder(appID: "3", bottleURL: bottle) == nil)
    }

    /// installdir ".." gibi bir değerle kütüphanenin dışına çıkılmaz.
    @Test func installDirMustStayInsideCommon() throws {
        let td = try TempDir()
        try td.file("\(Self.steamApps)/appmanifest_9.acf", manifest(appID: "9", installDir: ".."))
        try td.file("\(Self.steamApps)/appmanifest_8.acf", manifest(appID: "8", installDir: "a/../../.."))
        let bottle = td.url.appendingPathComponent("bottle")
        #expect(SteamLibrary.installFolder(appID: "9", bottleURL: bottle) == nil)
        #expect(SteamLibrary.installFolder(appID: "8", bottleURL: bottle) == nil)
    }
}
