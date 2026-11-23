import Foundation
import Testing
@testable import KopruCore

struct AntiCheatDetectorTests {
    @Test func easyAntiCheatFolderInGameRoot() throws {
        let td = try TempDir()
        try td.file("FallGuys/EasyAntiCheat/Settings.json", "{}")
        try td.file("FallGuys/FallGuys_client.exe")
        #expect(AntiCheatDetector.detect(inGameFolder: td.url.appendingPathComponent("FallGuys")) == .easyAntiCheat)
    }

    /// EAC'nin başlatıcısı tek başına da yeter (klasör adı farklı olabilir).
    @Test func protectedGameLauncherMeansEasyAntiCheat() throws {
        let td = try TempDir()
        try td.file("Oyun/start_protected_game.exe")
        #expect(AntiCheatDetector.detect(inGameFolder: td.url.appendingPathComponent("Oyun")) == .easyAntiCheat)
    }

    /// Unreal oyunlarında klasör Binaries/Win64 altında olabilir; adlar büyük/küçük harfe duyarsız.
    @Test func nestedAndLowercaseNamesAreFound() throws {
        let td = try TempDir()
        try td.file("Oyun/OyunGame/Binaries/Win64/easyanticheat_eos/x.cfg")
        #expect(AntiCheatDetector.detect(inGameFolder: td.url.appendingPathComponent("Oyun")) == .easyAntiCheat)
    }

    @Test func battlEyeFolderOrLauncher() throws {
        let td = try TempDir()
        try td.file("DayZ/BattlEye/BEService_x64.exe")
        try td.file("Arma/Arma3_BE.exe")
        #expect(AntiCheatDetector.detect(inGameFolder: td.url.appendingPathComponent("DayZ")) == .battlEye)
        #expect(AntiCheatDetector.detect(inGameFolder: td.url.appendingPathComponent("Arma")) == .battlEye)
    }

    @Test func easyAntiCheatWinsWhenBothArePresent() throws {
        let td = try TempDir()
        try td.file("Oyun/BattlEye/a.dll")
        try td.file("Oyun/EasyAntiCheat/b.dll")
        #expect(AntiCheatDetector.detect(inGameFolder: td.url.appendingPathComponent("Oyun")) == .easyAntiCheat)
    }

    @Test func gameWithoutAntiCheat() throws {
        let td = try TempDir()
        try td.file("AmongUs/Among Us.exe")
        try td.file("AmongUs/Among Us_Data/Plugins/x86_64/steam_api64.dll")
        #expect(AntiCheatDetector.detect(inGameFolder: td.url.appendingPathComponent("AmongUs")) == nil)
        #expect(AntiCheatDetector.detect(inGameFolder: td.url.appendingPathComponent("Yok")) == nil)
    }

    /// Tarama oyun klasöründen en fazla dört seviye iner; büyük oyunlarda ızgara beklemesin.
    @Test func searchStopsAtDepthLimit() throws {
        let td = try TempDir()
        try td.file("Oyun/a/b/c/d/EasyAntiCheat/x.cfg")
        try td.file("Sinir/a/b/c/start_protected_game.exe")
        #expect(AntiCheatDetector.detect(inGameFolder: td.url.appendingPathComponent("Oyun")) == nil)
        #expect(AntiCheatDetector.detect(inGameFolder: td.url.appendingPathComponent("Sinir")) == .easyAntiCheat)
    }

    // MARK: Kutucuğun oyun klasörü

    @Test func epicGameUsesItsInstallFolder() throws {
        let td = try TempDir()
        let bottle = try td.dir("bottle")
        try td.file("bottle/drive_c/Program Files/Epic Games/FallGuys/EasyAntiCheat/Settings.json", "{}")
        let game = EpicGame(name: "Fall Guys", appName: "fall",
                            executable: "C:\\Program Files\\Epic Games\\FallGuys\\FallGuys_client.exe",
                            installFolder: "C:\\Program Files\\Epic Games\\FallGuys",
                            launchURL: "com.epicgames.launcher://apps/x?action=launch&silent=true")
        let item = ProgramItem(name: game.name, source: .epicGame(game), target: .builtin("start", arguments: [game.launchURL]))
        #expect(AntiCheatDetector.detect(for: item, bottleURL: bottle) == .easyAntiCheat)
    }

    @Test func steamShortcutUsesLibraryFolder() throws {
        let td = try TempDir()
        let bottle = try td.dir("bottle")
        let steam = "bottle/drive_c/Program Files (x86)/Steam/steamapps"
        try td.file("\(steam)/appmanifest_730.acf", "\"AppState\"\n{\n\t\"appid\"\t\t\"730\"\n\t\"installdir\"\t\t\"Oyun\"\n}\n")
        try td.file("\(steam)/common/Oyun/EasyAntiCheat/Settings.json", "{}")
        let shortcut = ShortcutProgram(name: "Oyun", relativePath: "Steam/Oyun.url",
                                       url: td.url.appendingPathComponent("Oyun.url"), kind: .steamURL("steam://rungameid/730"))
        let item = ProgramItem(name: "Oyun", source: .shortcut(shortcut), target: .shortcut(shortcut.url))
        #expect(AntiCheatDetector.detect(for: item, bottleURL: bottle) == .easyAntiCheat)
    }

    /// Sabitlenen exe'ler ve .lnk kısayolları taranmaz.
    @Test func otherItemsAreNotChecked() throws {
        let td = try TempDir()
        let bottle = try td.dir("bottle")
        try td.file("bottle/drive_c/Oyun/EasyAntiCheat/x.cfg")
        let pinned = PinnedProgram(name: "Oyun", windowsPath: "C:\\Oyun\\oyun.exe")
        let item = ProgramItem(name: "Oyun", source: .pinned(pinned), target: .windowsPath(pinned.windowsPath, arguments: []))
        #expect(AntiCheatDetector.detect(for: item, bottleURL: bottle) == nil)
    }

    @Test func displayNames() {
        #expect(AntiCheat.easyAntiCheat.displayName == "Easy Anti-Cheat")
        #expect(AntiCheat.battlEye.displayName == "BattlEye")
    }
}
