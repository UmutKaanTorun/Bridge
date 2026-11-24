import Foundation
import Testing
@testable import KopruCore

/// Depodaki gerçek tarif ve katalog dosyaları.
struct RepositoryCatalogTests {
    static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // KopruCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // KopruCore
        .deletingLastPathComponent()   // depo kökü
        .appendingPathComponent("Resources", isDirectory: true)

    static func load() throws -> RecipeCatalog {
        try RecipeCatalog.load(recipesDirectory: resources.appendingPathComponent("Recipes"),
                               filesDirectory: resources.appendingPathComponent("RecipeFiles"),
                               upcomingFile: resources.appendingPathComponent("Catalog/upcoming.json"))
    }

    /// Sanal masaüstü Köprü'den kaldırıldı (Wine'ın Mac sürücüsünde yok); tariflerde ölü ayar kalmasın.
    @Test func recipesHaveNoVirtualDesktop() throws {
        let files = try FileManager.default.contentsOfDirectory(at: Self.resources.appendingPathComponent("Recipes"),
                                                                includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(!files.isEmpty)
        for file in files {
            #expect(!(try String(contentsOf: file, encoding: .utf8)).contains("virtualDesktop"), "\(file.lastPathComponent)")
        }
    }

    @Test func everyFileLoads() throws {
        let catalog = try Self.load()
        #expect(catalog.problems.isEmpty, "\(catalog.problems)")
        #expect(!catalog.recipes.isEmpty)
        #expect(!catalog.upcoming.isEmpty)
    }

    @Test func recipesCarryDisplayFieldsAndIcons() throws {
        let catalog = try Self.load()
        for recipe in catalog.recipes {
            #expect(recipe.publisher != nil, "\(recipe.id): yayıncı yok")
            #expect(recipe.verdict != nil, "\(recipe.id): açıklama yok")
            #expect(recipe.testedOn != nil, "\(recipe.id): test bilgisi yok")
            // Kur sayfası bütün platformları (çalışmayanlar dahil) simgesiyle gösterir.
            #expect(catalog.iconURL(for: recipe.id) != nil, "\(recipe.id): icon.png yok")
        }
    }

    @Test func upcomingIDsAreUniqueAndNotRecipes() throws {
        let file = Self.resources.appendingPathComponent("Catalog/upcoming.json")
        let ids = try JSONDecoder().decode([UpcomingProgram].self, from: Data(contentsOf: file)).map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(Set(try Self.load().recipes.map(\.id)).isDisjoint(with: ids))
    }

    @Test func recipeIDsMatchFileNames() throws {
        let folder = Self.resources.appendingPathComponent("Recipes")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(!files.isEmpty)
        for file in files {
            let recipe = try JSONDecoder().decode(Recipe.self, from: Data(contentsOf: file))
            #expect(recipe.id == file.deletingPathExtension().lastPathComponent, "\(file.lastPathComponent): id dosya adıyla aynı olmalı")
        }
    }

    @Test func everyRecipeHasDetectFiles() throws {
        for recipe in try Self.load().recipes {
            #expect(!recipe.detect.isEmpty, "\(recipe.id): detect boş; başarısız kurulum Kurulu görünür")
        }
    }

    /// Motorun wined3d'si varsayılan olarak Vulkan'ı (MoltenVK) seçer; orada D3D 10_0 yok. wined3d'ye
    /// alınan her program kurulumdan sonra OpenGL'e ayarlanmalı.
    @Test func wined3dProgramsAreSetToOpenGL() throws {
        let catalog = try Self.load()
        for recipe in catalog.recipes {
            for program in recipe.bottle.settings.wined3dPrograms ?? [] {
                let action = RecipeAction.registry(key: "HKCU\\Software\\Wine\\AppDefaults\\\(program)\\Direct3D",
                                                   name: "renderer", value: "gl")
                #expect(recipe.afterInstall.contains(action), "\(recipe.id): \(program) için renderer=gl yok")
            }
        }
        #expect(catalog.recipe(id: "rockstar")?.bottle.settings.wined3dPrograms == ["Launcher.exe"])
    }

    /// Game Mode yalnız oyunlarda açılsın: her tarif başlatıcının kendi süreçlerini (tarayıcı yardımcıları,
    /// servisler) oyun dışı sayar; motor yaması bunları paketsiz açar (Tools/motor-yamalari/ntdll-game-mode.patch).
    /// Aracı konan yardımcıların (helperProxy) hem kendisi hem `_gercek` kopyası listede olmalı.
    @Test func everyRecipeListsItsLauncherProcesses() throws {
        for recipe in try Self.load().recipes {
            let names = Set((recipe.nonGamePrograms ?? []).map { $0.lowercased() })
            #expect(!names.isEmpty, "\(recipe.id): nonGamePrograms boş")
            for case let .helperProxy(path) in recipe.afterInstall + recipe.beforeLaunch + (recipe.whileRunning ?? []) {
                let file = (path.components(separatedBy: "/").last ?? path).lowercased()
                #expect(names.contains(file), "\(recipe.id): \(file) oyun dışı listede yok")
                #expect(names.contains(file.replacingOccurrences(of: ".exe", with: "_gercek.exe")),
                        "\(recipe.id): \(file) gerçek kopyası oyun dışı listede yok")
            }
        }
        let steam = try #require(try Self.load().recipe(id: "steam"))
        #expect(steam.nonGamePrograms?.contains("steamwebhelper.exe") == true)
        #expect(steam.nonGamePrograms?.contains("steamwebhelper_gercek.exe") == true)
    }

    /// Rockstar'ın Launcher.exe'si görünür pencere açmadığı halde Dock'a düşüyor; pencereyi Social Club
    /// yardımcısı çiziyor ve Dock'ta iki aynı simge çıkıyordu. Motor yaması
    /// (Tools/motor-yamalari/winemac-dock-gizle.patch) ShowInDock="n" olan programı Dock'a koymaz.
    @Test func rockstarLauncherStaysOutOfDock() throws {
        let recipe = try #require(try Self.load().recipe(id: "rockstar"))
        let action = RecipeAction.registry(key: "HKCU\\Software\\Wine\\AppDefaults\\Launcher.exe\\Mac Driver",
                                           name: "ShowInDock", value: "n")
        #expect(recipe.afterInstall.contains(action))
    }

    /// steam.exe'nin görünür penceresi yok, Steam penceresini tarayıcı yardımcısı (steamwebhelper) çiziyor; ikisi de
    /// Dock'a düşünce iki aynı Steam simgesi çıkıyordu (oyunla birlikte üç). Kurulu bottle'lara da ulaşsın diye
    /// beforeLaunch'ta: değer yazılıysa Wine başlatılmaz (`WineRegistryFile`).
    @Test func steamClientStaysOutOfDock() throws {
        let recipe = try #require(try Self.load().recipe(id: "steam"))
        let action = RecipeAction.registry(key: "HKCU\\Software\\Wine\\AppDefaults\\steam.exe\\Mac Driver",
                                           name: "ShowInDock", value: "n")
        #expect(recipe.beforeLaunch.contains(action))
    }

    /// Her `helperProxy` eyleminin aracısı tarif dosyalarında, yardımcıyla aynı adla ve onu tanıtan işaretle var
    /// (Tools/cef-araci/derle.sh).
    @Test func helperProxiesAreBuilt() throws {
        let catalog = try Self.load()
        var count = 0
        for recipe in catalog.recipes {
            for case let .helperProxy(file) in recipe.afterInstall + recipe.beforeLaunch + (recipe.whileRunning ?? []) {
                let name = URL(fileURLWithPath: file).lastPathComponent
                let proxy = catalog.filesDirectory(for: recipe).appendingPathComponent(name)
                #expect(HelperProxy.isProxy(proxy, helperNamed: name), "\(recipe.id): \(name) aracısı yok ya da eski")
                count += 1
            }
        }
        #expect(count > 0)
    }
}
