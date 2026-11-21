import Foundation
@testable import KopruCore

extension Recipe {
    /// Testler için Steam benzeri tarif.
    static func fixture(
        id: String = "steam",
        name: String = "Steam",
        summary: String = "Oyun mağazası",
        category: RecipeCategory = .game,
        rating: RecipeRating = .works,
        publisher: String? = nil,
        installerURL: URL = URL(string: "https://example.invalid/SteamSetup.exe")!,
        sha256: String? = nil,
        afterInstall: [RecipeAction] = [],
        beforeLaunch: [RecipeAction] = [],
        detect: [String] = ["drive_c/Program Files (x86)/Steam/steam.exe"]
    ) -> Recipe {
        Recipe(
            schema: 1,
            id: id,
            name: name,
            summary: summary,
            category: category,
            rating: rating,
            bottle: RecipeBottle(defaultName: name,
                                 settings: BottleSettings(msync: true, fpsHud: false)),
            installer: RecipeInstallerSpec(url: installerURL, sha256: sha256, fileName: "SteamSetup.exe", arguments: ["/S"]),
            afterInstall: afterInstall,
            beforeLaunch: beforeLaunch,
            launch: RecipeLaunch(name: name,
                                 windowsPath: "C:\\Program Files (x86)\\Steam\\steam.exe",
                                 arguments: ["-noverifyfiles", "-no-cef-sandbox"],
                                 shutdownArguments: ["-shutdown"]),
            detect: detect,
            hideShortcuts: ["Steam/Steam.lnk"],
            publisher: publisher
        )
    }
}
