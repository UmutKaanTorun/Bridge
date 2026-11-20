import Foundation
import Testing
@testable import KopruCore

struct ProgramIconTests {
    private let icon = PEBuilder.Icon(id: 1, width: 32, image: Data(repeating: 0x5A, count: 50))

    private func bottle(_ td: TempDir) throws -> URL {
        try td.dir("Bottle/drive_c")
        return td.url.appendingPathComponent("Bottle", isDirectory: true)
    }

    @Test func recipeAndPinnedProgramsUseTheirExecutable() throws {
        let td = try TempDir()
        let bottleURL = try bottle(td)
        _ = try td.file("Bottle/drive_c/Program Files (x86)/Steam/steam.exe", data: PEBuilder.make(groups: [.init(id: 1, icons: [icon])]))
        let launch = RecipeLaunch(name: "Steam", windowsPath: "C:\\Program Files (x86)\\Steam\\steam.exe", arguments: [])
        let recipeItem = ProgramItem(name: "Steam", source: .recipe(launch), target: .windowsPath(launch.windowsPath, arguments: []))
        let pinned = PinnedProgram(name: "Steam", windowsPath: launch.windowsPath)
        let pinnedItem = ProgramItem(name: "Steam", source: .pinned(pinned), target: .windowsPath(pinned.windowsPath, arguments: []))

        for item in [recipeItem, pinnedItem] {
            let ico = try #require(ProgramIcon.icoData(for: item, bottleURL: bottleURL))
            #expect(icoEntries(ico)?.map(\.image) == [icon.image])
        }
    }

    @Test func steamGameShortcutReadsIcoFile() throws {
        let td = try TempDir()
        let bottleURL = try bottle(td)
        let icoBytes = Data([0, 0, 1, 0, 1, 0]) + Data(repeating: 7, count: 30)
        _ = try td.file("Bottle/drive_c/Steam/games/abc.ico", data: icoBytes)
        let file = try td.file("Bottle/kisayol.url", "[InternetShortcut]\nURL=steam://rungameid/1\nIconFile=C:\\Steam\\games\\abc.ico\n")
        let shortcut = ShortcutProgram(name: "Oyun", relativePath: "Oyun.url", url: file, kind: .steamURL("steam://rungameid/1"))
        let item = ProgramItem(name: "Oyun", source: .shortcut(shortcut), target: .shortcut(file))
        #expect(ProgramIcon.icoData(for: item, bottleURL: bottleURL) == icoBytes)
    }

    @Test func missingFilesGiveNoIcon() throws {
        let td = try TempDir()
        let bottleURL = try bottle(td)
        let launch = RecipeLaunch(name: "Yok", windowsPath: "C:\\yok.exe", arguments: [])
        let item = ProgramItem(name: "Yok", source: .recipe(launch), target: .windowsPath(launch.windowsPath, arguments: []))
        #expect(ProgramIcon.icoData(for: item, bottleURL: bottleURL) == nil)
    }
}
