import Foundation
import Testing
@testable import KopruCore

struct ProgramListTests {
    let steamLaunch = RecipeLaunch(name: "Steam", windowsPath: "C:\\Steam\\steam.exe",
                                   arguments: ["-noverifyfiles", "-no-cef-sandbox"], shutdownArguments: ["-shutdown"])
    let game = ShortcutProgram(name: "Thief", relativePath: "Steam/Thief.url",
                               url: URL(fileURLWithPath: "/B/Thief.url"), kind: .steamURL("steam://rungameid/2272420"))
    let notepad = ShortcutProgram(name: "Notepad++", relativePath: "Notepad++.lnk",
                                  url: URL(fileURLWithPath: "/B/Notepad++.lnk"), kind: .link)
    let pinned = PinnedProgram(name: "Araç", windowsPath: "C:\\arac.exe", arguments: ["-x"])

    @Test func orderIsRecipeThenPinnedThenShortcuts() {
        let items = ProgramList.items(recipeLaunch: steamLaunch, pinned: [pinned], shortcuts: [notepad, game])
        #expect(items.map(\.name) == ["Steam", "Araç", "Notepad++", "Thief"])
        #expect(Set(items.map(\.id)).count == 4)
        #expect(items[0].target == .windowsPath("C:\\Steam\\steam.exe", arguments: ["-noverifyfiles", "-no-cef-sandbox"]))
        #expect(items[1].target == .windowsPath("C:\\arac.exe", arguments: ["-x"]))
        #expect(items[2].target == .shortcut(URL(fileURLWithPath: "/B/Notepad++.lnk")))
    }

    @Test func steamGamesLaunchThroughRecipe() {
        let items = ProgramList.items(recipeLaunch: steamLaunch, pinned: [], shortcuts: [game])
        #expect(items.last?.target == .windowsPath("C:\\Steam\\steam.exe",
                                                   arguments: ["-noverifyfiles", "-no-cef-sandbox", "steam://rungameid/2272420"]))
    }

    @Test func steamGamesWithoutRecipeOpenAsShortcut() {
        let items = ProgramList.items(recipeLaunch: nil, pinned: [], shortcuts: [game])
        #expect(items.map(\.target) == [.shortcut(URL(fileURLWithPath: "/B/Thief.url"))])
    }
}
