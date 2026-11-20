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

/// Wine sanal masaüstü penceresi.
public struct DesktopWindow: Hashable, Sendable {
    public var name: String
    public var size: PixelSize

    public init(name: String, size: PixelSize) {
        self.name = name
        self.size = size
    }
}

public enum WineArguments {
    /// `wine` ikilisine verilecek argümanlar. Sanal masaüstü varsa komut explorer'a sarılır.
    public static func arguments(for target: LaunchTarget, desktop: DesktopWindow?) -> [String] {
        let inner: [String]
        switch target {
        case let .windowsPath(path, arguments):
            inner = [path] + arguments
        case let .shortcut(file):
            inner = ["start", "/wait", "/unix", file.path]
        case let .unixFile(file, arguments):
            inner = file.pathExtension.lowercased() == "msi"
                ? ["msiexec", "/i", file.path] + arguments
                : [file.path] + arguments
        case let .builtin(name, arguments):
            inner = [name] + arguments
        }
        guard let desktop else { return inner }
        return ["explorer", "/desktop=\(desktop.name),\(desktop.size.width)x\(desktop.size.height)"] + inner
    }
}
