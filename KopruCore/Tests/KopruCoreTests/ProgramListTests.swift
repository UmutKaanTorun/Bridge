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
    let bottleURL = URL(fileURLWithPath: "/olmayan/bottle")

    let epicLaunch = RecipeLaunch(name: "Epic Games Launcher",
                                  windowsPath: "C:\\Program Files\\Epic Games\\Launcher\\Portal\\Binaries\\Win64\\EpicGamesLauncher.exe",
                                  arguments: ["-SkipBuildPatchPrereq"])

    private func link(_ name: String, target: String?) -> ShortcutProgram {
        ShortcutProgram(name: name, relativePath: "\(name).lnk", url: URL(fileURLWithPath: "/B/\(name).lnk"),
                        kind: .link, target: target)
    }

    @Test func orderIsRecipeThenPinnedThenShortcuts() {
        let items = ProgramList.items(recipeLaunch: steamLaunch, pinned: [pinned], shortcuts: [notepad, game], bottleURL: bottleURL)
        #expect(items.map(\.name) == ["Steam", "Araç", "Notepad++", "Thief"])
        #expect(Set(items.map(\.id)).count == 4)
        #expect(items[0].target == .windowsPath("C:\\Steam\\steam.exe", arguments: ["-noverifyfiles", "-no-cef-sandbox"]))
        #expect(items[1].target == .windowsPath("C:\\arac.exe", arguments: ["-x"]))
        #expect(items[2].target == .shortcut(URL(fileURLWithPath: "/B/Notepad++.lnk")))
    }

    @Test func steamGamesLaunchThroughRecipe() {
        let items = ProgramList.items(recipeLaunch: steamLaunch, pinned: [], shortcuts: [game], bottleURL: bottleURL)
        #expect(items.last?.target == .windowsPath("C:\\Steam\\steam.exe",
                                                   arguments: ["-noverifyfiles", "-no-cef-sandbox", "steam://rungameid/2272420"]))
    }

    @Test func steamGamesWithoutRecipeOpenAsShortcut() {
        let items = ProgramList.items(recipeLaunch: nil, pinned: [], shortcuts: [game], bottleURL: bottleURL)
        #expect(items.map(\.target) == [.shortcut(URL(fileURLWithPath: "/B/Thief.url"))])
    }

    /// İstemci (SteamUI.dll) henüz yoksa Steam ilk açılış argümanlarıyla (doğrulama açık) başlar.
    @Test func recipeUsesFirstRunArgumentsUntilReadyFileExists() throws {
        let td = try TempDir()
        let bottle = try td.dir("bottle")
        var launch = steamLaunch
        launch.readyFile = "drive_c/Program Files (x86)/Steam/SteamUI.dll"
        launch.firstRunArguments = ["-no-cef-sandbox"]

        let first = ProgramList.items(recipeLaunch: launch, pinned: [], shortcuts: [], bottleURL: bottle)
        #expect(first.first?.target == .windowsPath("C:\\Steam\\steam.exe", arguments: ["-no-cef-sandbox"]))
        #expect(launch.arguments(forBottleAt: bottle) == ["-no-cef-sandbox"])

        try td.file("bottle/drive_c/Program Files (x86)/Steam/SteamUI.dll")
        let later = ProgramList.items(recipeLaunch: launch, pinned: [], shortcuts: [], bottleURL: bottle)
        #expect(later.first?.target == .windowsPath("C:\\Steam\\steam.exe", arguments: ["-noverifyfiles", "-no-cef-sandbox"]))
    }

    /// Kurulumun Başlat menüsüne koyduğu başlatıcı kısayolu tarifin kutucuğunun ikizi olmasın; tarifin
    /// argümanları atlanmasın. Rockstar'ınki Launcher.exe değil, aynı klasördeki LauncherPatcher.exe'yi gösterir.
    @Test func shortcutsIntoRecipeLauncherFolderAreHidden() {
        let shortcuts = [
            link("Epic Games Launcher", target: "c:\\program files\\epic games\\launcher\\portal\\binaries\\win64\\EpicGamesLauncher.exe"),
            link("Yama", target: "C:/Program Files/Epic Games/Launcher/Portal/Binaries/Win64/Patcher.exe"),
        ]
        let items = ProgramList.items(recipeLaunch: epicLaunch, pinned: [], shortcuts: shortcuts, bottleURL: bottleURL)
        #expect(items.map(\.name) == ["Epic Games Launcher"])
        #expect(items.first?.source == .recipe(epicLaunch))
    }

    /// Başlatıcının kurduğu oyunlar başka klasörde ya da alt klasördedir; görünür kalır.
    @Test func shortcutsOutsideRecipeLauncherFolderStay() {
        let shortcuts = [
            link("Alt", target: "C:\\Program Files\\Epic Games\\Launcher\\Portal\\Binaries\\Win64\\Games\\alt.exe"),
            link("Fortnite", target: "C:\\Program Files\\Epic Games\\Fortnite\\FortniteLauncher.exe"),
            link("Hedefsiz", target: nil),
        ]
        let items = ProgramList.items(recipeLaunch: epicLaunch, pinned: [], shortcuts: shortcuts, bottleURL: bottleURL)
        #expect(items.map(\.name) == ["Epic Games Launcher", "Alt", "Fortnite", "Hedefsiz"])
    }

    @Test func withoutRecipeLauncherShortcutsStay() {
        let shortcut = link("Epic Games Launcher", target: epicLaunch.windowsPath)
        let items = ProgramList.items(recipeLaunch: nil, pinned: [], shortcuts: [shortcut], bottleURL: bottleURL)
        #expect(items.map(\.name) == ["Epic Games Launcher"])
    }
}
