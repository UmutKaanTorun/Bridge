import Foundation
import Testing
@testable import KopruCore

struct EpicGameScannerTests {
    static let manifests = "bottle/drive_c/ProgramData/Epic/EpicGamesLauncher/Data/Manifests"

    /// Epic'in kendi .item dosyasına benzeyen kayıt (gerçek alanların bir kısmı).
    private func manifest(name: String, folder: String, exe: String, appName: String,
                          incomplete: Bool = false, executable: Bool = true, mainGame: String = "") -> String {
        """
        {
          "FormatVersion": 0,
          "bIsIncompleteInstall": \(incomplete),
          "LaunchCommand": "",
          "LaunchExecutable": "\(exe)",
          "bIsApplication": true,
          "bIsExecutable": \(executable),
          "AppCategories": ["public", "games", "applications"],
          "DisplayName": "\(name)",
          "InstallLocation": "C:\\\\Program Files\\\\Epic Games\\\\\(folder)",
          "CatalogNamespace": "ns-\(appName)",
          "CatalogItemId": "item-\(appName)",
          "AppName": "\(appName)",
          "MainGameAppName": "\(mainGame)"
        }
        """
    }

    /// Kaydı ve (istenirse) oyunun exe'sini oluşturur.
    private func install(_ td: TempDir, file: String, name: String, folder: String, exe: String, appName: String,
                         withExe: Bool = true, incomplete: Bool = false, executable: Bool = true, mainGame: String = "") throws {
        try td.file("\(Self.manifests)/\(file).item",
                    manifest(name: name, folder: folder, exe: exe, appName: appName,
                             incomplete: incomplete, executable: executable, mainGame: mainGame))
        if withExe { try td.file("bottle/drive_c/Program Files/Epic Games/\(folder)/\(exe)") }
    }

    @Test func findsInstalledGamesSortedByName() throws {
        let td = try TempDir()
        try install(td, file: "B", name: "Fall Guys", folder: "FallGuys", exe: "RunFallGuys.exe", appName: "fall")
        try install(td, file: "A", name: "Among Us", folder: "AmongUs", exe: "Among Us.exe", appName: "among")
        let games = EpicGameScanner.scan(bottleURL: td.url.appendingPathComponent("bottle"))
        #expect(games.map(\.name) == ["Among Us", "Fall Guys"])
        let among = try #require(games.first)
        #expect(among.appName == "among")
        #expect(among.executable == "C:\\Program Files\\Epic Games\\AmongUs\\Among Us.exe")
        #expect(among.launchURL == "com.epicgames.launcher://apps/ns-among%3Aitem-among%3Aamong?action=launch&silent=true")
    }

    /// Yarım kurulum, çalıştırılamayan kayıt, DLC ve exe'si diskte olmayan oyun listelenmez.
    @Test func skipsEntriesThatCannotBeLaunched() throws {
        let td = try TempDir()
        try install(td, file: "1", name: "Yarım", folder: "Yarim", exe: "y.exe", appName: "y", incomplete: true)
        try install(td, file: "2", name: "Araç", folder: "Arac", exe: "a.exe", appName: "a", executable: false)
        try install(td, file: "3", name: "Ek Paket", folder: "Ek", exe: "e.exe", appName: "e", mainGame: "among")
        try install(td, file: "4", name: "Silinmiş", folder: "Silinmis", exe: "s.exe", appName: "s", withExe: false)
        try install(td, file: "5", name: "Among Us", folder: "AmongUs", exe: "Among Us.exe", appName: "among")
        let games = EpicGameScanner.scan(bottleURL: td.url.appendingPathComponent("bottle"))
        #expect(games.map(\.name) == ["Among Us"])
    }

    @Test func brokenAndForeignFilesAreSkipped() throws {
        let td = try TempDir()
        try td.file("\(Self.manifests)/Bozuk.item", "{ yarım")
        try td.file("\(Self.manifests)/notlar.txt", "x")
        try td.dir("\(Self.manifests)/Pending")
        try install(td, file: "A", name: "Among Us", folder: "AmongUs", exe: "Among Us.exe", appName: "among")
        let games = EpicGameScanner.scan(bottleURL: td.url.appendingPathComponent("bottle"))
        #expect(games.map(\.name) == ["Among Us"])
    }

    @Test func bottleWithoutEpicHasNoGames() throws {
        let td = try TempDir()
        #expect(EpicGameScanner.scan(bottleURL: try td.dir("bos")).isEmpty)
    }
}
