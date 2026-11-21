import Foundation
import Testing
@testable import KopruCore

struct BottleInfoTests {
    @Test func writesAndReadsKopruJSON() throws {
        let td = try TempDir()
        let info = BottleInfo(
            name: "Oyunlarım",
            createdAt: Date(timeIntervalSince1970: 1_795_000_000),
            recipeId: "steam",
            settings: BottleSettings(msync: true, fpsHud: false),
            pinnedPrograms: [PinnedProgram(name: "Araç", windowsPath: "C:\\arac.exe")],
            hiddenShortcuts: ["Steam/Steam.lnk"]
        )
        try info.write(to: td.url)

        let json = try String(contentsOf: td.url.appendingPathComponent("kopru.json"), encoding: .utf8)
        #expect(json.contains(#""schema" : 1"#))
        #expect(json.contains(#""msync" : true"#))
        #expect(try BottleInfo.read(from: td.url) == info)
    }

    /// Sanal masaüstü kaldırılmadan önce kurulan bottle'ların kopru.json'u (alan okunurken yok sayılır).
    @Test func readsLegacyKopruJSONWithVirtualDesktop() throws {
        let td = try TempDir()
        let legacy = """
        {
          "createdAt" : "2026-11-20T16:54:59Z",
          "hiddenShortcuts" : [],
          "name" : "Steam",
          "pinnedPrograms" : [],
          "recipeId" : "steam",
          "schema" : 1,
          "settings" : { "fpsHud" : false, "msync" : true, "virtualDesktop" : { "mode" : "auto" } }
        }
        """
        try Data(legacy.utf8).write(to: td.url.appendingPathComponent("kopru.json"))
        let info = try BottleInfo.read(from: td.url)
        #expect(info.name == "Steam")
        #expect(info.settings == BottleSettings(msync: true, fpsHud: false))
    }

    @Test func missingRecipeIsOmitted() throws {
        let td = try TempDir()
        try BottleInfo(name: "Boş", createdAt: Date(timeIntervalSince1970: 0)).write(to: td.url)
        let json = try String(contentsOf: td.url.appendingPathComponent("kopru.json"), encoding: .utf8)
        #expect(!json.contains("recipeId"))
        #expect(try BottleInfo.read(from: td.url).recipeId == nil)
    }

    @Test func bottleDerivedPaths() {
        let bottle = Bottle(url: URL(fileURLWithPath: "/x/Bottles/Steam", isDirectory: true),
                            info: BottleInfo(name: "Steam", createdAt: Date(timeIntervalSince1970: 0)))
        #expect(bottle.id == "Steam")
        #expect(bottle.folderName == "Steam")
        #expect(bottle.driveC.path == "/x/Bottles/Steam/drive_c")
    }
}
