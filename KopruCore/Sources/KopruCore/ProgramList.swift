import Foundation

/// Program ızgarasındaki bir kutucuk.
public struct ProgramItem: Identifiable, Hashable, Sendable {
    public enum Source: Hashable, Sendable {
        case recipe(RecipeLaunch)
        case pinned(PinnedProgram)
        case shortcut(ShortcutProgram)
    }

    public let name: String
    public let source: Source
    public let target: LaunchTarget

    public var id: String {
        switch source {
        case let .recipe(launch): "recipe:\(launch.windowsPath)"
        case let .pinned(program): "pinned:\(program.windowsPath)"
        case let .shortcut(shortcut): "shortcut:\(shortcut.relativePath)"
        }
    }
}

public enum ProgramList {
    /// Sıra: tarif başlatıcısı, sabitlenenler, kısayollar.
    /// Steam oyunu kısayolları, tarif varsa tarifin başlatıcısıyla açılır (aracı ve seçenekler atlanmasın).
    /// Tarifin başlatıcısıyla aynı klasördeki bir programı gösteren kısayol (kurulumun kendi kısayolu) listelenmez:
    /// kutucuğun ikizi olur ve tarifin argümanları olmadan açılır.
    public static func items(recipeLaunch: RecipeLaunch?, pinned: [PinnedProgram], shortcuts: [ShortcutProgram],
                             bottleURL: URL) -> [ProgramItem] {
        var items: [ProgramItem] = []
        let recipeArguments = recipeLaunch?.arguments(forBottleAt: bottleURL) ?? []
        if let launch = recipeLaunch {
            items.append(ProgramItem(name: launch.name, source: .recipe(launch),
                                     target: .windowsPath(launch.windowsPath, arguments: recipeArguments)))
        }
        for program in pinned {
            items.append(ProgramItem(name: program.name, source: .pinned(program),
                                     target: .windowsPath(program.windowsPath, arguments: program.arguments)))
        }
        let launcherFolder = recipeLaunch.map { folder(of: $0.windowsPath) }
        for shortcut in shortcuts {
            if let launcherFolder, let shortcutTarget = shortcut.target, folder(of: shortcutTarget) == launcherFolder {
                continue
            }
            let target: LaunchTarget
            if case let .steamURL(url) = shortcut.kind, let launch = recipeLaunch {
                target = .windowsPath(launch.windowsPath, arguments: recipeArguments + [url])
            } else {
                target = .shortcut(shortcut.url)
            }
            items.append(ProgramItem(name: shortcut.name, source: .shortcut(shortcut), target: target))
        }
        return items
    }

    /// Windows yolunun klasörü, karşılaştırma için: "C:/A/b.exe" → "c:\\a".
    static func folder(of windowsPath: String) -> String {
        let path = windowsPath.replacingOccurrences(of: "/", with: "\\").lowercased()
        guard let slash = path.lastIndex(of: "\\") else { return "" }
        return String(path[..<slash])
    }
}
