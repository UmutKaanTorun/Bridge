import Foundation

/// Oyunun kullandığı anti-cheat. İkisinin de Wine için sunduğu modül yalnızca Linux'ta çalışıyor: EAC Wine'ı
/// görünce Linux modülünü indirip sürecin içine yüklemeye çalışıyor, macOS'ta yükleyemiyor ("Failed to load
/// the anti-cheat module", hata 206). Bu oyunlar Bridge'de büyük olasılıkla açılmaz.
public enum AntiCheat: String, Hashable, Sendable {
    case easyAntiCheat
    case battlEye

    public var displayName: String {
        switch self {
        case .easyAntiCheat: "Easy Anti-Cheat"
        case .battlEye: "BattlEye"
        }
    }
}

/// Oyun klasöründe anti-cheat dosyası arar. Yalnızca Epic oyunlarına ve Steam oyunu kısayollarına bakılır:
/// klasörleri platformun kayıtlarından bilinir. Sabitlenen exe'ler ve .lnk kısayolları taranmaz.
public enum AntiCheatDetector {
    /// Oyun klasöründen en fazla bu kadar seviye inilir (Unreal oyunları: Oyun/Binaries/Win64/EasyAntiCheat).
    static let maxDepth = 4

    public static func detect(for item: ProgramItem, bottleURL: URL) -> AntiCheat? {
        gameFolder(for: item, bottleURL: bottleURL).flatMap { detect(inGameFolder: $0) }
    }

    /// Epic oyununun kurulum klasörü ya da Steam kısayolunun kütüphanedeki klasörü; ötekiler için nil.
    static func gameFolder(for item: ProgramItem, bottleURL: URL) -> URL? {
        switch item.source {
        case let .epicGame(game):
            return WindowsPath.toUnix(game.installFolder, bottleURL: bottleURL)
        case let .shortcut(shortcut):
            guard case let .steamURL(url) = shortcut.kind, let appID = SteamLibrary.appID(fromURL: url) else { return nil }
            return SteamLibrary.installFolder(appID: appID, bottleURL: bottleURL)
        case .recipe, .pinned:
            return nil
        }
    }

    /// EAC ve BattlEye birlikte varsa EAC döner. Klasör yoksa ya da okunamıyorsa nil.
    public static func detect(inGameFolder folder: URL) -> AntiCheat? {
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey],
                                                              options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return nil
        }
        var found: AntiCheat?
        for case let url as URL in enumerator {
            if enumerator.level >= maxDepth { enumerator.skipDescendants() }
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            switch kind(name: url.lastPathComponent.lowercased(), isDirectory: isDirectory) {
            case .easyAntiCheat: return .easyAntiCheat
            case .battlEye: found = .battlEye
            case nil: break
            }
        }
        return found
    }

    /// Ad küçük harfle verilir.
    static func kind(name: String, isDirectory: Bool) -> AntiCheat? {
        if isDirectory {
            switch name {
            case "easyanticheat", "easyanticheat_eos": return .easyAntiCheat
            case "battleye": return .battlEye
            default: return nil
            }
        }
        if name == "start_protected_game.exe" { return .easyAntiCheat }
        if name.hasSuffix("_be.exe") { return .battlEye }
        return nil
    }
}
