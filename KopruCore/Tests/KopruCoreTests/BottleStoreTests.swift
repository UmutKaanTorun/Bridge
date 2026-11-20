import Foundation
import Testing
@testable import KopruCore

struct BottleStoreTests {
    @Test func emptyWhenNoBottlesFolder() throws {
        let td = try TempDir()
        #expect(try BottleStore(paths: td.paths).list().isEmpty)
    }

    @Test func makeBottleWritesFolderAndInfo() throws {
        let td = try TempDir()
        let store = BottleStore(paths: td.paths)
        let bottle = try store.makeBottle(name: "  Oyunlarım ", settings: .default, recipeId: "steam",
                                          now: Date(timeIntervalSince1970: 1_795_000_000))
        #expect(bottle.folderName == "Oyunlarim")
        #expect(bottle.info.name == "Oyunlarım")
        #expect(bottle.info.recipeId == "steam")
        #expect(FileManager.default.fileExists(atPath: bottle.url.appendingPathComponent("kopru.json").path))
        // URL'ler /var ↔ /private/var farkı yüzünden doğrudan karşılaştırılmaz; kimlik ve bilgi karşılaştırılır.
        #expect(try store.list().map(\.id) == [bottle.id])
        #expect(try store.list().first?.info == bottle.info)
    }

    @Test func rejectsEmptyAndDuplicateNames() throws {
        let td = try TempDir()
        let store = BottleStore(paths: td.paths)
        _ = try store.makeBottle(name: "Steam", settings: .default, recipeId: nil)
        #expect(throws: BottleStoreError.emptyName) { try store.makeBottle(name: "   ", settings: .default, recipeId: nil) }
        #expect(throws: BottleStoreError.nameTaken("steam")) { try store.makeBottle(name: "steam", settings: .default, recipeId: nil) }
    }

    @Test func differentNamesWithSameFolderGetNumbered() throws {
        let td = try TempDir()
        let store = BottleStore(paths: td.paths)
        _ = try store.makeBottle(name: "Oyun", settings: .default, recipeId: nil)
        let second = try store.makeBottle(name: "oyun!", settings: .default, recipeId: nil)
        #expect(second.folderName == "oyun-2")
    }

    @Test func listIsSortedAndSkipsForeignFolders() throws {
        let td = try TempDir()
        let store = BottleStore(paths: td.paths)
        for name in ["b", "A", "c"] { _ = try store.makeBottle(name: name, settings: .default, recipeId: nil) }
        try td.dir("AppSupport/Bottles/kopru-degil")
        #expect(try store.list().map(\.info.name) == ["A", "b", "c"])
    }

    @Test func renameKeepsFolder() throws {
        let td = try TempDir()
        let store = BottleStore(paths: td.paths)
        let steam = try store.makeBottle(name: "Steam", settings: .default, recipeId: nil)
        _ = try store.makeBottle(name: "Diğer", settings: .default, recipeId: nil)
        let renamed = try store.rename(steam, to: "Oyunlar")
        #expect(renamed.folderName == "Steam")
        #expect(try BottleInfo.read(from: steam.url).name == "Oyunlar")
        #expect(throws: BottleStoreError.nameTaken("Diğer")) { try store.rename(renamed, to: "Diğer") }
        #expect(try store.rename(renamed, to: "OYUNLAR").info.name == "OYUNLAR")
    }

    @Test func deleteUsesRemover() throws {
        let td = try TempDir()
        let store = BottleStore(paths: td.paths)
        let bottle = try store.makeBottle(name: "Sil", settings: .default, recipeId: nil)
        try store.delete(bottle, remover: { try FileManager.default.removeItem(at: $0) })
        #expect(try store.list().isEmpty)
    }

    @Test func importMovesBottleAndDetectsRecipe() throws {
        let td = try TempDir()
        try td.file("WineBottles/faz0-oyun26/system.reg", "WINE REGISTRY")
        try td.file("WineBottles/faz0-oyun26/drive_c/Program Files (x86)/Steam/steam.exe")
        let source = td.url.appendingPathComponent("WineBottles/faz0-oyun26")
        let catalog = RecipeCatalog(recipes: [.fixture()], filesDirectory: td.url)

        let bottle = try BottleStore(paths: td.paths).importBottle(from: source, name: "Steam (Faz 0)", catalog: catalog)

        #expect(bottle.folderName == "Steam-Faz-0")   // parantezler atılır, boşluklar tire olur
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: bottle.url.appendingPathComponent("drive_c/Program Files (x86)/Steam/steam.exe").path))
        #expect(bottle.info.recipeId == "steam")
        #expect(bottle.info.settings == Recipe.fixture().bottle.settings)
        #expect(try BottleInfo.read(from: bottle.url) == bottle.info)
    }

    @Test func importWithoutRecipeUsesDefaults() throws {
        let td = try TempDir()
        try td.file("eski/system.reg")
        try td.dir("eski/drive_c")
        let bottle = try BottleStore(paths: td.paths)
            .importBottle(from: td.url.appendingPathComponent("eski"), name: "Eski", catalog: nil)
        #expect(bottle.info.recipeId == nil)
        #expect(bottle.info.settings == BottleSettings(msync: true, virtualDesktop: .off, fpsHud: false))
    }

    @Test func importRejectsNonBottle() throws {
        let td = try TempDir()
        let folder = try td.dir("rastgele")
        #expect(throws: BottleStoreError.notAWineBottle(folder.path)) {
            try BottleStore(paths: td.paths).importBottle(from: folder, name: "X", catalog: nil)
        }
    }
}
