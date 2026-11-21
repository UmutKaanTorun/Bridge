import Foundation

/// Wine'a ne çalıştırılacağı.
public enum LaunchTarget: Hashable, Sendable {
    /// Bottle içindeki Windows yolu: `wine C:\…\x.exe args`
    case windowsPath(String, arguments: [String])
    /// Başlat menüsü kısayolu (.lnk/.url): `wine start /wait /unix <dosya>`;
    /// /wait sayesinde süreç program kapanana kadar yaşar.
    case shortcut(URL)
    /// Mac'teki bir dosya: .exe doğrudan, .msi msiexec ile.
    case unixFile(URL, arguments: [String])
    /// Wine'ın kendi programları: wineboot, winecfg, reg, cmd…
    case builtin(String, arguments: [String])
}

public enum WineArguments {
    /// `wine` ikilisine verilecek argümanlar. Sanal masaüstü (`explorer /desktop`) kullanılmaz: Wine'ın Mac
    /// sürücüsünde yok, yalnız yan etkileri kalıyordu (bkz. `BottleSettings`).
    public static func arguments(for target: LaunchTarget) -> [String] {
        switch target {
        case let .windowsPath(path, arguments):
            [path] + arguments
        case let .shortcut(file):
            ["start", "/wait", "/unix", file.path]
        case let .unixFile(file, arguments):
            file.pathExtension.lowercased() == "msi"
                ? ["msiexec", "/i", file.path] + arguments
                : [file.path] + arguments
        case let .builtin(name, arguments):
            [name] + arguments
        }
    }
}
