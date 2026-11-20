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
    public static func items(recipeLaunch: RecipeLaunch?, pinned: [PinnedProgram], shortcuts: [ShortcutProgram]) -> [ProgramItem] {
        var items: [ProgramItem] = []
        if let launch = recipeLaunch {
            items.append(ProgramItem(name: launch.name, source: .recipe(launch),
                                     target: .windowsPath(launch.windowsPath, arguments: launch.arguments)))
        }
        for program in pinned {
            items.append(ProgramItem(name: program.name, source: .pinned(program),
                                     target: .windowsPath(program.windowsPath, arguments: program.arguments)))
        }
        for shortcut in shortcuts {
            let target: LaunchTarget
            if case let .steamURL(url) = shortcut.kind, let launch = recipeLaunch {
                target = .windowsPath(launch.windowsPath, arguments: launch.arguments + [url])
            } else {
                target = .shortcut(shortcut.url)
            }
            items.append(ProgramItem(name: shortcut.name, source: .shortcut(shortcut), target: target))
        }
        return items
    }
}
