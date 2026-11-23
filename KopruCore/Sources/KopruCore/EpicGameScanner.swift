import Foundation

/// Epic Games Launcher'ın kurduğu oyun. Epic oyunlarına Başlat menüsü kısayolu koymaz;
/// oyunlar Epic'in kendi kayıt dosyalarından (`Manifests/*.item`) okunur.
public struct EpicGame: Hashable, Sendable, Identifiable {
    public let name: String
    /// Epic'teki uygulama kimliği (`AppName`).
    public let appName: String
    /// Oyunun exe'si (Windows yolu); simge buradan okunur.
    public let executable: String
    /// Oyunun kurulum klasörü (Windows yolu); anti-cheat burada aranır.
    public let installFolder: String
    /// Epic'in oyunu açtığı bağlantı. Oyunlar Epic hesabıyla açıldığı için exe doğrudan çalıştırılmaz.
    public let launchURL: String

    public var id: String { appName }
}

public enum EpicGameScanner {
    static let manifestsSubpath = "drive_c/ProgramData/Epic/EpicGamesLauncher/Data/Manifests"

    private struct Manifest: Decodable {
        let DisplayName: String
        let InstallLocation: String
        let LaunchExecutable: String
        let AppName: String
        let CatalogNamespace: String
        let CatalogItemId: String
        let bIsIncompleteInstall: Bool?
        let bIsExecutable: Bool?
        let MainGameAppName: String?
    }

    /// Açılabilen oyunlar, ada göre sıralı. Yarım kurulum, çalıştırılamayan kayıt, ek paket (DLC)
    /// ve exe'si diskte olmayan oyun alınmaz; okunamayan kayıt atlanır.
    public static func scan(bottleURL: URL) -> [EpicGame] {
        let folder = bottleURL.appendingPathComponent(manifestsSubpath, isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var games: [EpicGame] = []
        for file in files where file.pathExtension.lowercased() == "item" {
            guard let data = try? Data(contentsOf: file),
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
                  manifest.bIsIncompleteInstall != true, manifest.bIsExecutable != false,
                  manifest.MainGameAppName?.isEmpty != false, !manifest.LaunchExecutable.isEmpty else { continue }
            let location = manifest.InstallLocation.hasSuffix("\\") ? String(manifest.InstallLocation.dropLast()) : manifest.InstallLocation
            let executable = location + "\\" + manifest.LaunchExecutable.replacingOccurrences(of: "/", with: "\\")
            guard let unix = WindowsPath.toUnix(executable, bottleURL: bottleURL),
                  FileManager.default.fileExists(atPath: unix.path) else { continue }
            let id = [manifest.CatalogNamespace, manifest.CatalogItemId, manifest.AppName].joined(separator: "%3A")
            games.append(EpicGame(name: manifest.DisplayName, appName: manifest.AppName, executable: executable,
                                  installFolder: location,
                                  launchURL: "com.epicgames.launcher://apps/\(id)?action=launch&silent=true"))
        }
        return games.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
