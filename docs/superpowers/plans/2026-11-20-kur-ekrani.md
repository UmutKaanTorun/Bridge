# Program Kur Ekranı Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Amaç:** v0.1'in küçük "Kur penceresi"ni (sheet), ana pencerede kenar çubuğundan açılan bir **Program kur** sayfasına dönüştürmek. Sayfada arama, kategoriler, uyumluluk etiketli kartlar ve seçili programın ayrıntısıyla kurulum ilerlemesini gösteren bir sağ panel olacak.

**Mimari:** Veri tarafı (tarif alanları, "Yakında" listesi, kategori ve arama, `CatalogEntry`) testli `KopruCore` paketine eklenir. Arayüz tarafında `AppModel` kenar çubuğu seçimini (`SidebarItem`) ve kurulumun kaynağını (`InstallSource`) taşır. Yeni SwiftUI görünümleri şunlar: `InstallPage`, `CatalogCard`, `InstallInspector`, `UnlistedDetail`, `DropOverlay`. `InstallSheet` silinir; `InstallProgressView` yalnızca "Boş Bottle…" için kalır.

**Teknolojiler:** Swift 6, SwiftUI (macOS 14: `.inspector`, `ContentUnavailableView`, `@Entry`), Observation, Swift Testing, XcodeGen, Xcode 27.1. Üçüncü taraf bağımlılık yok.

**Spec:** `docs/superpowers/specs/2026-11-20-kur-ekrani-design.md` (görsel taslak: `docs/superpowers/specs/2026-11-20-kur-ekrani-taslak.html`)

## Genel Kısıtlar

- macOS 14.0+, yalnızca Apple Silicon. Swift 6 dil modu.
- Görünen ad **Köprü**; dosya, klasör ve kod adı **Kopru**.
- Tür ve fonksiyon adları İngilizce; kod açıklamaları ve arayüz metinleri Türkçe. Arayüz metinleri `Text("...")` gibi literallerle yazılır (String Catalog `Kopru/Localizable.xcstrings`, kaynak dil `tr`).
- Testler Swift Testing ile (`import Testing`, `@Test`, `#expect`). Çalıştırma: `cd KopruCore && swift test`. Ağ ve motor isteyen testler ortam değişkeni olmadan atlanır.
- Uygulama derleme: `xcodegen generate && xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build -quiet build`
- Depo kökü `~/Developer/Kopru`; komutlar aksi yazmadıkça depo kökünden çalıştırılır.
- Uyumluluk etiketleri (birebir): `perfect` **Sorunsuz** (yeşil), `works` **Çalışıyor** (camgöbeği), `partial` **Kısmen çalışıyor** (turuncu), `broken` **Şimdilik çalışmıyor** (kırmızı); tarifsiz girdi **Test ediliyor** (gri).
- Kategoriler (birebir): `game` Oyun, `business` İş ve muhasebe, `engineering` Mühendislik, `office` Ofis.
- Pencere en küçük 1040 × 560 pt. Sağ panel 300–420 pt, varsayılan 340 pt.
- Bir anda tek kurulum. Kurulum bitince sayfa değişmez.
- Bu oturumların ekran kaydı ve erişilebilirlik izni yok: arayüzü **Umut** dener. Her arayüz görevinin sonunda Umut'a kısa bir kontrol listesi verilir ve onayı alınır.
- Her commit mesajı şu satırla biter:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  ```

## Başlamadan Önce

- [ ] `git status --short` boş olmalı. Başka bir oturumun exe simgeleri işi (`WindowsIcon.swift`, `ShortcutIcon.swift`, `AppModel.swift`/`ProgramGrid.swift` değişiklikleri) commit'lenmeden başlama; bu plan aynı dosyalara dokunur ve `WindowsIcon.swift`'i kullanır. Boş değilse dur, Umut'a sor.
- [ ] `gelistirme/v0.1` dalından yeni dal aç: `git switch -c gelistirme/kur-ekrani`
- [ ] `cd KopruCore && swift test` geçmeli (başlangıç durumu).

## Dosya Haritası

```
Resources/
├─ Recipes/steam.json                 (değişir) yayıncı, açıklama, test bilgisi, indirme notu, ayarlar listesi
├─ Recipes/notepadpp.json             (yeni, Görev 9)
├─ Recipes/winrar.json                (yeni, Görev 9)
├─ RecipeFiles/<id>/icon.png          (yeni) tarif simgeleri
└─ Catalog/upcoming.json              (yeni) "Yakında" listesi
Tools/tarif-simgesi/                  (yeni) exe'den icon.png çıkaran araç
KopruCore/Sources/KopruCore/
├─ Recipe.swift                       (değişir) RecipeRating.perfect, RecipeCategory, RecipeTestInfo, RecipeHighlight, yeni alanlar
├─ UpcomingProgram.swift              (yeni) UpcomingProgram, UpcomingStatus
├─ CatalogEntry.swift                 (yeni) CatalogEntry, CatalogSections, SearchText
├─ RecipeCatalog.swift                (değişir) dosya dosya okuma, upcoming, sections, count, categories, entry, iconURL
└─ Bottle.swift                       (değişir) [Bottle].withRecipe(_:)
KopruCore/Tests/KopruCoreTests/
├─ TestSupport/RecipeFixture.swift    (değişir) category/rating/publisher parametreleri
├─ RecipeTests.swift                  (değişir)
├─ RecipeCatalogTests.swift           (değişir)
├─ BottleTests.swift                  (yeni)
└─ RepositoryCatalogTests.swift       (yeni) depodaki gerçek dosyalar
Kopru/
├─ KopruApp.swift                     (değişir) en küçük pencere, ⌘F komutu
├─ AppModel.swift                     (değişir) SidebarItem, InstallSource, seçim ve kurulum durumu
└─ Views/
   ├─ ContentView.swift               (değişir) sayfa seçimi, araç çubuğu, sürükle-bırak katmanı
   ├─ BottleSidebar.swift             (değişir) "Program kur" satırı, tarif simgesi
   ├─ InstallPage.swift               (yeni) başlık, arama, kategoriler, bölümler
   ├─ CatalogCard.swift               (yeni) kart
   ├─ CatalogVisuals.swift            (yeni) RatingBadge, EntryIcon, renk eşlemesi
   ├─ InstallInspector.swift          (yeni) sağ panel: ayrıntı, eylemler, ilerleme
   ├─ UnlistedDetail.swift            (yeni) listede olmayan dosya paneli
   ├─ InstallStepsList.swift          (yeni) adım listesi (panel + sheet ortak)
   ├─ DropOverlay.swift               (yeni) "Bırak, kuralım" katmanı
   ├─ WindowsInstallers.swift         (yeni) UTType.windowsInstallers (InstallSheet'ten taşınır)
   ├─ InstallProgressView.swift       (değişir) yalnızca boş bottle sheet'i
   └─ InstallSheet.swift              (silinir, Görev 7)
```

---

### Görev 1: Tarif modeline Kur sayfası alanları

**Files:**
- Modify: `KopruCore/Sources/KopruCore/Recipe.swift`
- Modify: `KopruCore/Tests/KopruCoreTests/TestSupport/RecipeFixture.swift`
- Modify: `KopruCore/Tests/KopruCoreTests/RecipeTests.swift`
- Modify: `Resources/Recipes/steam.json`

**Interfaces:**
- Produces:
  - `enum RecipeRating: String { case perfect, works, partial, broken; var label: String }`
  - `enum RecipeCategory: String, CaseIterable { case game, business, engineering, office; var label: String; var symbolName: String }`
  - `struct RecipeTestInfo { var date: String; var hardware: String; var macOS: String; var summary: String }` (`summary` → `"20 Kas 2026 · Apple M3 · macOS 26.6"`)
  - `struct RecipeHighlight { var title: String; var detail: String }`
  - `Recipe.category: RecipeCategory` (önceden `String`), yeni isteğe bağlı alanlar `publisher: String?`, `verdict: String?`, `testedOn: RecipeTestInfo?`, `downloadNote: String?`, `highlights: [RecipeHighlight]?`
  - `Recipe.fixture(id:name:summary:category:rating:publisher:installerURL:sha256:afterInstall:beforeLaunch:detect:)` (testler)

- [ ] **Adım 1: Fixture'ı yeni parametrelerle yaz**

`KopruCore/Tests/KopruCoreTests/TestSupport/RecipeFixture.swift` dosyasının tamamı:

```swift
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
                                 settings: BottleSettings(msync: true, virtualDesktop: .auto, fpsHud: false)),
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
```

- [ ] **Adım 2: Başarısız testleri yaz**

`KopruCore/Tests/KopruCoreTests/RecipeTests.swift` içinde `ratingLabels` testini sil, `struct RecipeTests` gövdesinin sonuna şunları ekle:

```swift
    @Test func ratingLabels() throws {
        #expect(RecipeRating.perfect.label == "Sorunsuz")
        #expect(RecipeRating.works.label == "Çalışıyor")
        #expect(RecipeRating.partial.label == "Kısmen çalışıyor")
        #expect(RecipeRating.broken.label == "Şimdilik çalışmıyor")
        #expect(try JSONDecoder().decode(RecipeRating.self, from: Data(#""perfect""#.utf8)) == .perfect)
    }

    @Test func categoryLabelsAndSymbols() {
        #expect(RecipeCategory.allCases.map(\.label) == ["Oyun", "İş ve muhasebe", "Mühendislik", "Ofis"])
        #expect(RecipeCategory.allCases.map(\.symbolName) == ["gamecontroller", "building.columns", "ruler", "doc.text"])
    }

    @Test func decodesSteamDisplayFields() throws {
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(contentsOf: Self.steamJSON))
        #expect(recipe.category == .game)
        #expect(recipe.publisher == "Valve")
        #expect(recipe.summary == "Oyun mağazası ve başlatıcısı")
        #expect(recipe.testedOn == RecipeTestInfo(date: "2026-11-20", hardware: "Apple M3", macOS: "26.6"))
        #expect(recipe.highlights?.map(\.title) == ["Tarayıcı yardımcısı düzeltmesi", "Sanal masaüstü",
                                                    "Steam katmanı kapalı", "MSync açık"])
        #expect(recipe.verdict?.isEmpty == false)
        #expect(recipe.downloadNote?.isEmpty == false)
    }

    @Test func displayFieldsAreOptional() throws {
        let data = try JSONEncoder().encode(Recipe.fixture())
        let text = String(decoding: data, as: UTF8.self)
        for key in ["publisher", "verdict", "testedOn", "downloadNote", "highlights"] {
            #expect(!text.contains(key), "\(key) boşken yazılmamalı")
        }
        let recipe = try JSONDecoder().decode(Recipe.self, from: data)
        #expect(recipe.publisher == nil)
        #expect(recipe.verdict == nil)
        #expect(recipe.testedOn == nil)
        #expect(recipe.downloadNote == nil)
        #expect(recipe.highlights == nil)
    }

    @Test func rejectsUnknownCategory() throws {
        let text = String(decoding: try JSONEncoder().encode(Recipe.fixture()), as: UTF8.self)
            .replacingOccurrences(of: #""category":"game""#, with: #""category":"mutfak""#)
        #expect(text.contains("mutfak"))
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Recipe.self, from: Data(text.utf8))
        }
    }

    @Test func testInfoSummary() {
        #expect(RecipeTestInfo(date: "2026-11-20", hardware: "Apple M3", macOS: "26.6").summary
                == "20 Kas 2026 · Apple M3 · macOS 26.6")
        #expect(RecipeTestInfo(date: "yakında", hardware: "Apple M3", macOS: "26.6").summary
                == "yakında · Apple M3 · macOS 26.6")
    }
```

- [ ] **Adım 3: Testlerin başarısız olduğunu gör**

Çalıştır: `cd KopruCore && swift test --filter RecipeTests`
Beklenen: Derleme hatası ("type 'RecipeCategory' has no member…", "extra argument 'publisher'").

- [ ] **Adım 4: Modeli yaz**

`KopruCore/Sources/KopruCore/Recipe.swift` içinde `RecipeRating` tanımını tamamen şununla değiştir ve hemen altına yeni türleri ekle:

```swift
/// Tarifin uyumluluk notu.
public enum RecipeRating: String, Codable, Hashable, Sendable {
    case perfect, works, partial, broken

    public var label: String {
        switch self {
        case .perfect: "Sorunsuz"
        case .works: "Çalışıyor"
        case .partial: "Kısmen çalışıyor"
        case .broken: "Şimdilik çalışmıyor"
        }
    }
}

/// Kur sayfasındaki kategori.
public enum RecipeCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case game, business, engineering, office

    public var label: String {
        switch self {
        case .game: "Oyun"
        case .business: "İş ve muhasebe"
        case .engineering: "Mühendislik"
        case .office: "Ofis"
        }
    }

    /// Simgesi olmayan programın yerine gösterilen SF Symbol.
    public var symbolName: String {
        switch self {
        case .game: "gamecontroller"
        case .business: "building.columns"
        case .engineering: "ruler"
        case .office: "doc.text"
        }
    }
}

/// Tarifin son test edildiği ortam.
public struct RecipeTestInfo: Codable, Hashable, Sendable {
    /// "yyyy-MM-dd"
    public var date: String
    public var hardware: String
    public var macOS: String

    public init(date: String, hardware: String, macOS: String) {
        self.date = date
        self.hardware = hardware
        self.macOS = macOS
    }

    /// "20 Kas 2026 · Apple M3 · macOS 26.6"; tarih okunamazsa olduğu gibi yazılır.
    public var summary: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd"
        var day = date
        if let parsed = parser.date(from: date) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "d MMM yyyy"
            day = formatter.string(from: parsed)
        }
        return "\(day) · \(hardware) · macOS \(macOS)"
    }
}

/// Panelde "Köprü senin yerine ayarlar" altında bir madde. Tarifte gerçekten yapılan bir şeye karşılık gelmeli.
public struct RecipeHighlight: Codable, Hashable, Sendable {
    public var title: String
    public var detail: String

    public init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }
}
```

Aynı dosyada `Recipe` yapısında `public var category: String` satırını `public var category: RecipeCategory` yap ve `public var hideShortcuts: [String]` satırının altına ekle:

```swift
    // Kur sayfası alanları; hepsi isteğe bağlı, eski tarifler bunlarsız da çözülür.
    public var publisher: String?
    /// Neyin çalışıp neyin çalışmadığını anlatan cümle.
    public var verdict: String?
    public var testedOn: RecipeTestInfo?
    /// Ör. "2 MB, ilk açılışta …"
    public var downloadNote: String?
    public var highlights: [RecipeHighlight]?
```

- [ ] **Adım 5: Steam tarifini güncelle**

`Resources/Recipes/steam.json` dosyasının başını (`"rating"` satırına kadar) şununla değiştir; `"bottle"` ve sonrası aynen kalır:

```json
{
  "schema": 1,
  "id": "steam",
  "name": "Steam",
  "publisher": "Valve",
  "summary": "Oyun mağazası ve başlatıcısı",
  "category": "game",
  "rating": "works",
  "verdict": "Giriş, mağaza, kütüphane ve oyun indirme çalışıyor; denenen oyun açıldı. Oyun içi Steam katmanı kapalı.",
  "testedOn": { "date": "2026-11-20", "hardware": "Apple M3", "macOS": "26.6" },
  "downloadNote": "2 MB kurulum dosyası; ilk açılışta Steam kendini günceller (diskte yaklaşık 1,9 GB)",
  "highlights": [
    { "title": "Tarayıcı yardımcısı düzeltmesi", "detail": "Mağaza penceresi siyah açılmaz" },
    { "title": "Sanal masaüstü", "detail": "Pencere sol üste yapışmaz, kesilmez" },
    { "title": "Steam katmanı kapalı", "detail": "Oyun açılırken çökmeyi önler" },
    { "title": "MSync açık", "detail": "Oyunlarda daha akıcı kare hızı" }
  ],
```

(1,9 GB, Köprü'deki Steam bottle'ında ölçüldü: `Program Files (x86)/Steam`, oyunsuz.)

- [ ] **Adım 6: Testlerin geçtiğini gör**

Çalıştır: `cd KopruCore && swift test`
Beklenen: Hepsi geçer (ağ/motor testleri atlanır).

- [ ] **Adım 7: Uygulamanın derlendiğini gör**

Çalıştır: `xcodegen generate && xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build -quiet build`
Beklenen: Hatasız biter.

- [ ] **Adım 8: Commit**

```bash
git add KopruCore/Sources/KopruCore/Recipe.swift KopruCore/Tests/KopruCoreTests/TestSupport/RecipeFixture.swift KopruCore/Tests/KopruCoreTests/RecipeTests.swift Resources/Recipes/steam.json
git commit -m "KopruCore: tarife Kur sayfası alanları, Sorunsuz etiketi ve kategoriler

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 2: Katalog — Yakında listesi, bölümler, Türkçe arama, kurulu bottle

**Files:**
- Create: `KopruCore/Sources/KopruCore/UpcomingProgram.swift`
- Create: `KopruCore/Sources/KopruCore/CatalogEntry.swift`
- Modify: `KopruCore/Sources/KopruCore/RecipeCatalog.swift`
- Modify: `KopruCore/Sources/KopruCore/Bottle.swift`
- Modify: `KopruCore/Tests/KopruCoreTests/RecipeCatalogTests.swift`
- Create: `KopruCore/Tests/KopruCoreTests/BottleTests.swift`

**Interfaces:**
- Consumes: Görev 1'deki `RecipeCategory`, `RecipeRating`, `Recipe.publisher`, `Recipe.fixture(...)`.
- Produces:
  - `enum UpcomingStatus: String { case testing, broken; var label: String }`
  - `struct UpcomingProgram: Identifiable { id, name: String; publisher: String?; summary: String; category: RecipeCategory; status: UpcomingStatus; note: String? }`
  - `enum CatalogEntry: Identifiable { case recipe(Recipe), upcoming(UpcomingProgram); id ("recipe:<id>" / "upcoming:<id>"), name, publisher, summary, category, isReady }`
  - `struct CatalogSections { ready: [CatalogEntry]; upcoming: [CatalogEntry]; isEmpty }`
  - `RecipeCatalog.init(recipes:upcoming:filesDirectory:problems:)` (son ikisi varsayılanlı), `RecipeCatalog.load(recipesDirectory:filesDirectory:upcomingFile:)`, `.upcoming`, `.problems: [String]`, `.sections(matching:category:) -> CatalogSections`, `.count(in: RecipeCategory?) -> Int`, `.categories: [RecipeCategory]`, `.entry(id: CatalogEntry.ID?) -> CatalogEntry?`, `.iconURL(for recipeID: String) -> URL?`
  - `extension Array where Element == Bottle { func withRecipe(_ id: String) -> [Bottle] }`
  - `RecipeCatalog.search(_:)` bu görevde **kalır** (eski `InstallSheet` kullanıyor); Görev 7'de silinir.

- [ ] **Adım 1: Başarısız testleri yaz**

`KopruCore/Tests/KopruCoreTests/RecipeCatalogTests.swift` içinde `struct RecipeCatalogTests {` satırının hemen altına ekle:

```swift
    static let sample = RecipeCatalog(
        recipes: [.fixture(id: "steam", name: "Steam", summary: "Oyun mağazası ve başlatıcısı", publisher: "Valve"),
                  .fixture(id: "winrar", name: "WinRAR", summary: "Arşivleme, RAR ve ZIP açma",
                           category: .office, rating: .perfect),
                  .fixture(id: "notepadpp", name: "Notepad++", summary: "Kod ve metin düzenleyici",
                           category: .office, rating: .perfect),
                  .fixture(id: "eski", name: "Eski Başlatıcı", summary: "Artık açılmıyor", rating: .broken)],
        upcoming: [UpcomingProgram(id: "logo", name: "Logo Go 3 / Tiger", publisher: "Logo Yazılım",
                                   summary: "Ön muhasebe ve ticari yazılım", category: .business, status: .testing)],
        filesDirectory: URL(fileURLWithPath: "/tmp/RecipeFiles"))

    @Test func sectionsSplitReadyAndUpcomingByName() {
        let sections = Self.sample.sections(matching: "", category: nil)
        #expect(sections.ready.map(\.name) == ["Notepad++", "Steam", "WinRAR"])
        #expect(sections.upcoming.map(\.name) == ["Eski Başlatıcı", "Logo Go 3 / Tiger"])
    }

    @Test func searchMatchesNameSummaryPublisherAndFoldsTurkish() {
        func names(_ query: String) -> [String] {
            let sections = Self.sample.sections(matching: query, category: nil)
            return (sections.ready + sections.upcoming).map(\.name)
        }
        #expect(names("NOTEPAD") == ["Notepad++"])
        #expect(names("valve") == ["Steam"])
        #expect(names("baslaticisi") == ["Steam"])
        #expect(names("arsivleme") == ["WinRAR"])
        #expect(names("  logo ") == ["Logo Go 3 / Tiger"])
        #expect(names("yok").isEmpty)
        #expect(Self.sample.sections(matching: "yok", category: nil).isEmpty)
    }

    @Test func categoryFilterCombinesWithSearch() {
        #expect(Self.sample.sections(matching: "", category: .office).ready.map(\.name) == ["Notepad++", "WinRAR"])
        #expect(Self.sample.sections(matching: "steam", category: .office).isEmpty)
        #expect(Self.sample.sections(matching: "", category: .business).upcoming.map(\.name) == ["Logo Go 3 / Tiger"])
    }

    @Test func countsAndCategoriesIgnoreSearch() {
        #expect(Self.sample.count(in: nil) == 5)
        #expect(Self.sample.count(in: .office) == 2)
        #expect(Self.sample.count(in: .engineering) == 0)
        #expect(Self.sample.categories == [.game, .business, .office])
    }

    @Test func findsEntryByID() {
        #expect(Self.sample.entry(id: "recipe:steam")?.name == "Steam")
        #expect(Self.sample.entry(id: "upcoming:logo")?.isReady == false)
        #expect(Self.sample.entry(id: "recipe:eski")?.isReady == false)
        #expect(Self.sample.entry(id: nil) == nil)
        #expect(Self.sample.entry(id: "recipe:yok") == nil)
    }

    @Test func brokenRecipeFileDoesNotEmptyCatalog() throws {
        let td = try TempDir()
        let recipes = try td.dir("Recipes")
        try JSONEncoder().encode(Recipe.fixture(id: "alfa", name: "Alfa")).write(to: recipes.appendingPathComponent("alfa.json"))
        try td.file("Recipes/bozuk.json", "{")
        let catalog = try RecipeCatalog.load(recipesDirectory: recipes, filesDirectory: td.url)
        #expect(catalog.recipes.map(\.id) == ["alfa"])
        #expect(catalog.problems.count == 1)
        #expect(catalog.problems.first?.hasPrefix("bozuk.json") == true)
    }

    @Test func loadsUpcomingAndDropsEntriesThatHaveRecipes() throws {
        let td = try TempDir()
        let recipes = try td.dir("Recipes")
        try JSONEncoder().encode(Recipe.fixture()).write(to: recipes.appendingPathComponent("steam.json"))
        let upcoming = try td.file("upcoming.json", """
        [{"id":"steam","name":"Steam","summary":"x","category":"game","status":"testing"},
         {"id":"gog-galaxy","name":"GOG Galaxy","publisher":"GOG","summary":"Oyun mağazası","category":"game","status":"testing"},
         {"id":"epic","name":"Epic Games Launcher","summary":"Oyun mağazası","category":"game","status":"broken","note":"Takılıyor."}]
        """)
        let catalog = try RecipeCatalog.load(recipesDirectory: recipes, filesDirectory: td.url, upcomingFile: upcoming)
        #expect(catalog.upcoming.map(\.id) == ["epic", "gog-galaxy"])
        #expect(catalog.upcoming.first?.note == "Takılıyor.")
        #expect(catalog.upcoming.last?.publisher == "GOG")
        #expect(catalog.problems.isEmpty)
    }

    @Test func missingUpcomingFileLeavesListEmpty() throws {
        let td = try TempDir()
        let catalog = try RecipeCatalog.load(recipesDirectory: try td.dir("Recipes"), filesDirectory: td.url,
                                             upcomingFile: td.url.appendingPathComponent("yok.json"))
        #expect(catalog.upcoming.isEmpty)
        #expect(catalog.problems.count == 1)
    }

    @Test func iconURLOnlyWhenFileExists() throws {
        let td = try TempDir()
        let catalog = RecipeCatalog(recipes: [.fixture()], filesDirectory: td.url)
        #expect(catalog.iconURL(for: "steam") == nil)
        try td.file("steam/icon.png", "png")
        #expect(catalog.iconURL(for: "steam")?.lastPathComponent == "icon.png")
    }
```

`KopruCore/Tests/KopruCoreTests/BottleTests.swift` oluştur:

```swift
import Foundation
import Testing
@testable import KopruCore

struct BottleTests {
    @Test func filtersBottlesByRecipe() {
        let steam = Bottle(url: URL(fileURLWithPath: "/tmp/Steam"),
                           info: BottleInfo(name: "Steam", createdAt: .now, recipeId: "steam"))
        let empty = Bottle(url: URL(fileURLWithPath: "/tmp/Bos"), info: BottleInfo(name: "Boş", createdAt: .now))
        #expect([steam, empty].withRecipe("steam").map(\.id) == ["Steam"])
        #expect([steam, empty].withRecipe("winrar").isEmpty)
    }
}
```

- [ ] **Adım 2: Testlerin başarısız olduğunu gör**

Çalıştır: `cd KopruCore && swift test --filter "RecipeCatalogTests|BottleTests"`
Beklenen: Derleme hatası (`UpcomingProgram`, `sections`, `withRecipe` yok).

- [ ] **Adım 3: Yeni türleri yaz**

`KopruCore/Sources/KopruCore/UpcomingProgram.swift`:

```swift
import Foundation

/// "Yakında" girdisinin durumu.
public enum UpcomingStatus: String, Codable, Hashable, Sendable {
    case testing, broken

    public var label: String {
        switch self {
        case .testing: "Test ediliyor"
        case .broken: "Şimdilik çalışmıyor"
        }
    }
}

/// Tarifi henüz olmayan, test edilen program (Resources/Catalog/upcoming.json).
public struct UpcomingProgram: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// Emin olunmayan yayıncı yazılmaz.
    public var publisher: String?
    public var summary: String
    public var category: RecipeCategory
    public var status: UpcomingStatus
    /// Çalışmayan programda kullanıcıya gösterilen açıklama.
    public var note: String?

    public init(id: String, name: String, publisher: String? = nil, summary: String,
                category: RecipeCategory, status: UpcomingStatus, note: String? = nil) {
        self.id = id
        self.name = name
        self.publisher = publisher
        self.summary = summary
        self.category = category
        self.status = status
        self.note = note
    }
}
```

`KopruCore/Sources/KopruCore/CatalogEntry.swift`:

```swift
import Foundation

/// Kur sayfasındaki bir kart: tarif ya da "Yakında" girdisi.
public enum CatalogEntry: Identifiable, Hashable, Sendable {
    case recipe(Recipe)
    case upcoming(UpcomingProgram)

    public var id: String {
        switch self {
        case let .recipe(recipe): "recipe:\(recipe.id)"
        case let .upcoming(program): "upcoming:\(program.id)"
        }
    }

    public var name: String {
        switch self {
        case let .recipe(recipe): recipe.name
        case let .upcoming(program): program.name
        }
    }

    public var publisher: String? {
        switch self {
        case let .recipe(recipe): recipe.publisher
        case let .upcoming(program): program.publisher
        }
    }

    public var summary: String {
        switch self {
        case let .recipe(recipe): recipe.summary
        case let .upcoming(program): program.summary
        }
    }

    public var category: RecipeCategory {
        switch self {
        case let .recipe(recipe): recipe.category
        case let .upcoming(program): program.category
        }
    }

    /// "Kurulmaya hazır" bölümünde mi? Çalışmayan tarifler ve tarifsiz girdiler "Yakında"dadır.
    public var isReady: Bool {
        if case let .recipe(recipe) = self { recipe.rating != .broken } else { false }
    }

    /// Katlanmış sorgu adda, özette ya da yayıncıda geçiyor mu? Boş sorgu her şeyle eşleşir.
    func matches(folded query: String) -> Bool {
        query.isEmpty || [name, summary, publisher ?? ""].contains { SearchText.fold($0).contains(query) }
    }
}

/// Kur sayfasının iki bölümü.
public struct CatalogSections: Equatable, Sendable {
    public var ready: [CatalogEntry]
    public var upcoming: [CatalogEntry]

    public var isEmpty: Bool { ready.isEmpty && upcoming.isEmpty }
}

/// Arama için metin katlama.
enum SearchText {
    /// Büyük/küçük harf, aksan ve Türkçe ı/i farkını siler: "BAŞLATICISI" → "baslaticisi", "İş" → "is".
    static func fold(_ text: String) -> String {
        let turkish = Locale(identifier: "tr_TR")
        return text.lowercased(with: turkish)
            .folding(options: .diacriticInsensitive, locale: turkish)
            .replacingOccurrences(of: "ı", with: "i")
    }
}
```

- [ ] **Adım 4: Kataloğu yaz**

`KopruCore/Sources/KopruCore/RecipeCatalog.swift` dosyasının tamamı:

```swift
import Foundation

/// Uygulamanın içindeki tarifler ve "Yakında" listesi.
public struct RecipeCatalog: Sendable {
    public let recipes: [Recipe]
    /// Tarifi henüz olmayan, test edilen programlar; tarifle aynı id'yi taşıyanlar elenmiş.
    public let upcoming: [UpcomingProgram]
    /// Tariflere ait ek dosyalar: <filesDirectory>/<tarif id>/...
    public let filesDirectory: URL
    /// Okunamayan dosyalar ve nedenleri; uygulama günlüğe yazar.
    public let problems: [String]

    public init(recipes: [Recipe], upcoming: [UpcomingProgram] = [], filesDirectory: URL, problems: [String] = []) {
        self.recipes = recipes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let recipeIDs = Set(recipes.map(\.id))
        self.upcoming = upcoming
            .filter { !recipeIDs.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        self.filesDirectory = filesDirectory
        self.problems = problems
    }

    /// Klasördeki .json tariflerini tek tek okur; okunamayan dosya atlanır ve `problems`'a yazılır.
    /// `upcomingFile` yoksa ya da okunamazsa "Yakında" listesi boş kalır.
    public static func load(recipesDirectory: URL, filesDirectory: URL, upcomingFile: URL? = nil) throws -> RecipeCatalog {
        let files = try FileManager.default
            .contentsOfDirectory(at: recipesDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "json" }
        let decoder = JSONDecoder()
        var recipes: [Recipe] = []
        var problems: [String] = []
        for file in files {
            do {
                recipes.append(try decoder.decode(Recipe.self, from: Data(contentsOf: file)))
            } catch {
                problems.append("\(file.lastPathComponent): \(error)")
            }
        }
        var upcoming: [UpcomingProgram] = []
        if let upcomingFile {
            do {
                upcoming = try decoder.decode([UpcomingProgram].self, from: Data(contentsOf: upcomingFile))
            } catch {
                problems.append("\(upcomingFile.lastPathComponent): \(error)")
            }
        }
        return RecipeCatalog(recipes: recipes, upcoming: upcoming, filesDirectory: filesDirectory, problems: problems)
    }

    /// Ad ve özette büyük/küçük harf ve aksan duyarsız arama; boş sorgu hepsini döndürür.
    /// Yalnızca eski Kur penceresi için; Görev 7'de silinir.
    public func search(_ query: String) -> [Recipe] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return recipes }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return recipes.filter {
            $0.name.range(of: q, options: options) != nil || $0.summary.range(of: q, options: options) != nil
        }
    }

    public func recipe(id: String?) -> Recipe? {
        guard let id else { return nil }
        return recipes.first { $0.id == id }
    }

    public func filesDirectory(for recipe: Recipe) -> URL {
        filesDirectory.appendingPathComponent(recipe.id, isDirectory: true)
    }

    /// Tarifin simgesi (RecipeFiles/<id>/icon.png); dosya yoksa nil.
    public func iconURL(for recipeID: String) -> URL? {
        let url = filesDirectory.appendingPathComponent(recipeID, isDirectory: true).appendingPathComponent("icon.png")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Bottle'da `detect` dosyalarının hepsi bulunan ilk tarif.
    public func detect(in bottleURL: URL) -> Recipe? {
        recipes.first { recipe in
            !recipe.detect.isEmpty && recipe.detect.allSatisfy {
                FileManager.default.fileExists(atPath: bottleURL.appendingPathComponent($0).path)
            }
        }
    }

    // MARK: Kur sayfası

    private var allEntries: [CatalogEntry] {
        recipes.map(CatalogEntry.recipe) + upcoming.map(CatalogEntry.upcoming)
    }

    /// Süzgeçten geçen kartlar ada göre sıralı: hazır tarifler ve "Yakında" (çalışmayan tarifler + tarifsizler).
    public func sections(matching query: String, category: RecipeCategory?) -> CatalogSections {
        let folded = SearchText.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        let entries = allEntries
            .filter { (category == nil || $0.category == category) && $0.matches(folded: folded) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return CatalogSections(ready: entries.filter(\.isReady), upcoming: entries.filter { !$0.isReady })
    }

    /// Kategori kapsülündeki sayı (aramadan bağımsız); nil = hepsi.
    public func count(in category: RecipeCategory?) -> Int {
        allEntries.filter { category == nil || $0.category == category }.count
    }

    /// En az bir kartı olan kategoriler, `allCases` sırasıyla.
    public var categories: [RecipeCategory] {
        RecipeCategory.allCases.filter { count(in: $0) > 0 }
    }

    public func entry(id: CatalogEntry.ID?) -> CatalogEntry? {
        guard let id else { return nil }
        return allEntries.first { $0.id == id }
    }
}
```

`KopruCore/Sources/KopruCore/Bottle.swift` dosyasının sonuna ekle:

```swift
public extension Array where Element == Bottle {
    /// Tarifin kurulu olduğu bottle'lar (kopru.json'daki recipeId).
    func withRecipe(_ id: String) -> [Bottle] {
        filter { $0.info.recipeId == id }
    }
}
```

- [ ] **Adım 5: Testlerin geçtiğini gör**

Çalıştır: `cd KopruCore && swift test`
Beklenen: Hepsi geçer.

- [ ] **Adım 6: Uygulamanın derlendiğini gör**

Çalıştır: `xcodegen generate && xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build -quiet build`
Beklenen: Hatasız.

- [ ] **Adım 7: Commit**

```bash
git add KopruCore/Sources/KopruCore/UpcomingProgram.swift KopruCore/Sources/KopruCore/CatalogEntry.swift KopruCore/Sources/KopruCore/RecipeCatalog.swift KopruCore/Sources/KopruCore/Bottle.swift KopruCore/Tests/KopruCoreTests/RecipeCatalogTests.swift KopruCore/Tests/KopruCoreTests/BottleTests.swift
git commit -m "KopruCore: Yakında listesi, katalog bölümleri, Türkçe arama, bozuk tarif dosyası kataloğu boşaltmaz

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 3: Yakında dosyası, simge aracı ve Steam simgesi

**Files:**
- Create: `Resources/Catalog/upcoming.json`
- Modify: `project.yml`
- Create: `Tools/tarif-simgesi/main.swift`, `Tools/tarif-simgesi/simge.sh`
- Create: `Resources/RecipeFiles/steam/icon.png` (araçla üretilir)
- Create: `KopruCore/Tests/KopruCoreTests/RepositoryCatalogTests.swift`
- Modify: `Kopru/AppModel.swift` (katalog yükleme)

**Interfaces:**
- Consumes: Görev 2'deki `RecipeCatalog.load(recipesDirectory:filesDirectory:upcomingFile:)`, `.problems`, `.iconURL(for:)`, `UpcomingProgram`.
- Produces: Uygulama paketinde `Contents/Resources/Catalog/upcoming.json`; `Tools/tarif-simgesi/simge.sh "<program.exe>" <tarif-id>` → `Resources/RecipeFiles/<tarif-id>/icon.png`.

- [ ] **Adım 1: Depo dosyaları için başarısız testi yaz**

`KopruCore/Tests/KopruCoreTests/RepositoryCatalogTests.swift`:

```swift
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
            if recipe.rating != .broken {
                #expect(catalog.iconURL(for: recipe.id) != nil, "\(recipe.id): icon.png yok")
            }
        }
    }

    @Test func upcomingIDsAreUniqueAndNotRecipes() throws {
        let file = Self.resources.appendingPathComponent("Catalog/upcoming.json")
        let ids = try JSONDecoder().decode([UpcomingProgram].self, from: Data(contentsOf: file)).map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(Set(try Self.load().recipes.map(\.id)).isDisjoint(with: ids))
    }
}
```

- [ ] **Adım 2: Testin başarısız olduğunu gör**

Çalıştır: `cd KopruCore && swift test --filter RepositoryCatalogTests`
Beklenen: FAIL; `upcoming.json` yok (`problems` dolu, `upcoming` boş) ve `steam: icon.png yok`.

- [ ] **Adım 3: Yakında listesini yaz**

`Resources/Catalog/upcoming.json` (kaynak: Sheets "Faz 0 Test Listesi" → "Testler"; Steam'den kurulan oyunlar ve ürün adı olmayan e-imza satırı alınmadı; yayıncısından emin olunmayanlarda `publisher` yok):

```json
[
  { "id": "epic", "name": "Epic Games Launcher", "publisher": "Epic Games",
    "summary": "Oyun mağazası ve başlatıcısı", "category": "game", "status": "broken",
    "note": "Başlatıcı ilk kurulumda takılıyor. Yeni motor sürümüyle yeniden denenecek." },
  { "id": "gog-galaxy", "name": "GOG Galaxy", "publisher": "GOG",
    "summary": "Oyun mağazası ve başlatıcısı", "category": "game", "status": "testing" },
  { "id": "logo", "name": "Logo Go 3 / Tiger", "publisher": "Logo Yazılım",
    "summary": "Ön muhasebe ve ticari yazılım", "category": "business", "status": "testing" },
  { "id": "eta-sql", "name": "ETA:SQL",
    "summary": "Ticari ve muhasebe yazılımı", "category": "business", "status": "testing" },
  { "id": "mikro", "name": "Mikro", "publisher": "Mikro Yazılım",
    "summary": "Ticari ve muhasebe yazılımı", "category": "business", "status": "testing" },
  { "id": "matriks", "name": "Matriks",
    "summary": "Borsa veri terminali", "category": "business", "status": "testing" },
  { "id": "excel-2016", "name": "Excel 2016", "publisher": "Microsoft",
    "summary": "Makrolu (VBA) tablolar", "category": "office", "status": "testing" },
  { "id": "netcad", "name": "NetCAD", "publisher": "Netcad",
    "summary": "Harita, CBS ve CAD", "category": "engineering", "status": "testing" },
  { "id": "idecad", "name": "ideCAD Statik",
    "summary": "Yapı tasarımı ve statik analiz", "category": "engineering", "status": "testing" }
]
```

- [ ] **Adım 4: Simge aracını yaz**

`Tools/tarif-simgesi/main.swift`:

```swift
import Foundation

// Windows programındaki simgeyi .ico olarak yazar (KopruCore/WindowsIcon.swift ile birlikte derlenir).
let args = CommandLine.arguments
guard args.count == 3, let ico = WindowsIcon.icoData(fromExecutable: URL(fileURLWithPath: args[1])) else {
    FileHandle.standardError.write(Data("kullanım: tarif-simgesi <program.exe> <çıktı.ico>\n".utf8))
    exit(1)
}
try ico.write(to: URL(fileURLWithPath: args[2]))
```

`Tools/tarif-simgesi/simge.sh`:

```sh
#!/bin/sh
# Bir Windows programının simgesini tarif simgesi yapar:
#   Tools/tarif-simgesi/simge.sh "<program.exe>" <tarif-id>
# → Resources/RecipeFiles/<tarif-id>/icon.png (exe'deki en büyük boyut, genelde 256 px)
set -eu
[ $# -eq 2 ] || { echo "kullanım: $0 <program.exe> <tarif-id>" >&2; exit 1; }
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
swiftc -O -o "$tmp/tarif-simgesi" Tools/tarif-simgesi/main.swift KopruCore/Sources/KopruCore/WindowsIcon.swift
"$tmp/tarif-simgesi" "$1" "$tmp/simge.ico"
mkdir -p "Resources/RecipeFiles/$2"
sips -s format png "$tmp/simge.ico" --out "Resources/RecipeFiles/$2/icon.png" >/dev/null
sips -g pixelWidth "Resources/RecipeFiles/$2/icon.png" | tail -1
```

Çalıştır: `chmod +x Tools/tarif-simgesi/simge.sh`

- [ ] **Adım 5: Steam simgesini üret**

Çalıştır: `Tools/tarif-simgesi/simge.sh "$HOME/Library/Application Support/Kopru/Bottles/Steam/drive_c/Program Files (x86)/Steam/steam.exe" steam`
Beklenen: `pixelWidth: 256`. (Bu yol yoksa: `$HOME/WineBottles/faz0-oyun26/drive_c/Program Files (x86)/Steam/steam.exe`.)

- [ ] **Adım 6: Kaynak klasörünü projeye ekle**

`project.yml` içinde `Resources/RecipeFiles` girdisinin altına ekle:

```yaml
      - path: Resources/Catalog
        type: folder
        buildPhase: resources
```

- [ ] **Adım 7: Uygulamada kataloğu Yakında listesiyle yükle**

`Kopru/AppModel.swift` başına `import os` ekle ve `@MainActor` satırının üstüne:

```swift
private let catalogLog = Logger(subsystem: "dev.kopru.Kopru", category: "katalog")
```

`init()` içinde `catalog = (try? RecipeCatalog.load(...)) ?? RecipeCatalog(...)` ifadesini şununla değiştir:

```swift
        do {
            catalog = try RecipeCatalog.load(recipesDirectory: resources.appendingPathComponent("Recipes", isDirectory: true),
                                             filesDirectory: recipeFiles,
                                             upcomingFile: resources.appendingPathComponent("Catalog/upcoming.json"))
        } catch {
            catalogLog.error("Tarif klasörü okunamadı: \(error.localizedDescription, privacy: .public)")
            catalog = RecipeCatalog(recipes: [], filesDirectory: recipeFiles)
        }
        for problem in catalog.problems {
            catalogLog.error("Okunamayan katalog dosyası: \(problem, privacy: .public)")
        }
```

- [ ] **Adım 8: Testlerin geçtiğini, dosyaların pakete girdiğini gör**

Çalıştır: `cd KopruCore && swift test`
Beklenen: Hepsi geçer.

Çalıştır: `xcodegen generate && xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build -quiet build && ls build/Build/Products/Debug/Kopru.app/Contents/Resources/Catalog build/Build/Products/Debug/Kopru.app/Contents/Resources/RecipeFiles/steam`
Beklenen: `upcoming.json`; `icon.png  steamwebhelper.exe`.

- [ ] **Adım 9: Commit**

```bash
git add Resources/Catalog/upcoming.json project.yml Tools/tarif-simgesi Resources/RecipeFiles/steam/icon.png KopruCore/Tests/KopruCoreTests/RepositoryCatalogTests.swift Kopru/AppModel.swift
git commit -m "Yakında listesi, tarif simgesi aracı ve Steam simgesi; katalog sorunları günlüğe yazılır

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 4: AppModel — kenar çubuğu seçimi ve kurulum kaynağı

**Files:**
- Modify: `Kopru/AppModel.swift`

**Interfaces:**
- Consumes: `CatalogEntry`, `RecipeCatalog.entry(id:)`, `[Bottle].withRecipe(_:)`.
- Produces (Görev 5–9 bunları kullanır):
  - `enum SidebarItem: Hashable { case install, bottle(Bottle.ID) }`
  - `enum InstallSource: Hashable { case recipe(String), unlisted(URL), emptyBottle }`
  - `InstallProgress.source: InstallSource` (ilk alan; `InstallProgress(source:title:steps:createsBottle:)`)
  - `AppModel.selection: SidebarItem?`, `selectedBottleID: Bottle.ID?` (artık `selection`'dan türetilir, yazılabilir), `isBottlePage: Bool`
  - `AppModel.selectedEntryID: CatalogEntry.ID?`, `selectedEntry: CatalogEntry?`, `selectEntry(_:)`
  - `AppModel.unlistedFile: URL?`, `unlistedDefaultBottleID: Bottle.ID?`, `showInstallPage(unlisted: URL? = nil)`
  - `AppModel.isInstallRunning: Bool`, `installedBottle(for: CatalogEntry) -> Bottle?`, `launchRecipe(in: Bottle)`, `closeInstallPanel()`, `showRunningInstall()`

- [ ] **Adım 1: Türleri ekle**

`Kopru/AppModel.swift` içinde `enum UnlistedTarget` tanımının altına ekle:

```swift
/// Kenar çubuğunda seçili satır.
enum SidebarItem: Hashable {
    case install
    case bottle(Bottle.ID)
}

/// Kurulumun nereden başladığı; kart ve panel kendi kurulumunu bununla tanır.
enum InstallSource: Hashable {
    /// Tarif id'si
    case recipe(String)
    case unlisted(URL)
    case emptyBottle
}
```

`struct InstallProgress` içinde `let id = UUID()` satırının altına ekle:

```swift
    let source: InstallSource
```

- [ ] **Adım 2: Seçim durumunu yaz**

`var selectedBottleID: Bottle.ID?` satırını şununla değiştir:

```swift
    var selection: SidebarItem?
    /// Kur sayfasında seçili kart.
    var selectedEntryID: CatalogEntry.ID?
    /// Kur sayfası panelinde gösterilen listede olmayan kurulum dosyası; doluyken kart seçimi yerine o görünür.
    var unlistedFile: URL?
    /// Listede olmayan dosya için önerilen bottle (dosya bırakılmadan önce bakılan bottle).
    var unlistedDefaultBottleID: Bottle.ID?

    /// Seçili bottle; Kur sayfasındayken nil. Eski görünümler için yazılabilir.
    var selectedBottleID: Bottle.ID? {
        get { if case let .bottle(id) = selection { id } else { nil } }
        set { selection = newValue.map(SidebarItem.bottle) }
    }
```

`// MARK: Durum` bölümüne, `var isReady` satırının altına ekle:

```swift
    var isBottlePage: Bool { if case .bottle = selection { true } else { false } }

    var isInstallRunning: Bool { install?.isActive == true }

    var selectedEntry: CatalogEntry? { catalog.entry(id: selectedEntryID) }

    /// Kartın tarifinin kurulu olduğu ilk bottle.
    func installedBottle(for entry: CatalogEntry) -> Bottle? {
        guard case let .recipe(recipe) = entry else { return nil }
        return bottles.withRecipe(recipe.id).first
    }
```

- [ ] **Adım 3: `reload` seçimi korusun**

`reload(select:)` içinde şu iki satırı:

```swift
        if let id { selectedBottleID = id }
        if selectedBottle == nil { selectedBottleID = bottles.first?.id }
```

şununla değiştir:

```swift
        if let id { selection = .bottle(id) }
        // Seçim yoksa ya da seçili bottle silindiyse: ilk bottle, o da yoksa Kur sayfası.
        if selection == nil || (isBottlePage && selectedBottle == nil) {
            selection = bottles.first.map { .bottle($0.id) } ?? .install
        }
```

- [ ] **Adım 4: Kur sayfası eylemlerini ekle**

`// MARK: Programları açma` bölümünde `runExecutable` fonksiyonunun üstüne ekle:

```swift
    /// Tarifin başlatıcısını verilen bottle'da açar (Kur sayfasındaki "Aç"); sayfa değişmez.
    func launchRecipe(in bottle: Bottle) {
        guard let runner, let launch = recipe(for: bottle)?.launch else { return }
        let target = LaunchTarget.windowsPath(launch.windowsPath, arguments: launch.arguments(forBottleAt: bottle.url))
        start(target, name: launch.name, in: bottle, runner: runner)
    }
```

`// MARK: Kurulum` başlığının hemen altına ekle:

```swift
    /// Kur sayfasına geçer; `file` verilirse panel o kurulum dosyasını gösterir.
    func showInstallPage(unlisted file: URL? = nil) {
        if let file {
            unlistedDefaultBottleID = selectedBottleID
            unlistedFile = file
        }
        selection = .install
    }

    func selectEntry(_ id: CatalogEntry.ID) {
        selectedEntryID = id
        unlistedFile = nil
    }

    /// Süren kurulumun paneline döner.
    func showRunningInstall() {
        switch install?.source {
        case let .recipe(id):
            selectedEntryID = catalog.recipe(id: id).map { CatalogEntry.recipe($0).id }
            unlistedFile = nil
            selection = .install
        case let .unlisted(file):
            showInstallPage(unlisted: file)
        case .emptyBottle, nil:
            break
        }
    }

    /// Paneldeki biten ya da başarısız kurulumu kapatır; listede olmayan dosyanın panelini de temizler.
    func closeInstallPanel() {
        if case .unlisted = install?.source { unlistedFile = nil }
        install = nil
    }
```

- [ ] **Adım 5: Kurulumlara kaynak ver, bitince sayfayı değiştirme**

`installRecipe` içinde:

```swift
        install = InstallProgress(source: .recipe(recipe.id), title: "\(recipe.name) kuruluyor",
                                  steps: InstallStep.allCases, createsBottle: true)
```

`installUnlisted` içinde:

```swift
        install = InstallProgress(source: .unlisted(file),
                                  title: "\(file.lastPathComponent) kuruluyor",
                                  steps: createsBottle ? [.preparing, .installing] : [.installing],
                                  createsBottle: createsBottle)
```

`createEmptyBottle` içinde:

```swift
        install = InstallProgress(source: .emptyBottle, title: "\(name) oluşturuluyor", steps: [.preparing], createsBottle: true)
```

`apply(_:)` sonundaki satırı:

```swift
        if case let .bottleCreated(bottle) = event { reload(select: bottle.id) }
```

şununla değiştir (kurulum sürerken kullanıcı Kur sayfasında gezinebilir; bottle yalnızca listede belirir):

```swift
        if case .bottleCreated = event { reload() }
```

`finishInstall(_:)` sonundaki `reload(select: bottle.id)` satırını şununla değiştir:

```swift
        // Kur sayfasından başlayan kurulumda sayfa değişmez; kenar çubuğundan açılan boş bottle seçilir.
        if install?.source == .emptyBottle { reload(select: bottle.id) } else { reload() }
```

`deleteFailedInstallBottle()` sonundaki `install = nil` satırını `closeInstallPanel()` yap.

- [ ] **Adım 6: Derle**

Çalıştır: `xcodegen generate && xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build -quiet build`
Beklenen: Hatasız. (Eski `BottleSidebar` `$model.selectedBottleID` ile çalışmaya devam eder.)

- [ ] **Adım 7: Uygulamayı aç, eski akışın bozulmadığını gör**

Çalıştır: `open build/Build/Products/Debug/Kopru.app`
Umut'a sor: Bottle listesi ve seçim eskisi gibi mi, Kur penceresi açılıyor mu? (Kurulum yapmaya gerek yok.)

- [ ] **Adım 8: Commit**

```bash
git add Kopru/AppModel.swift
git commit -m "Uygulama: kenar çubuğu seçimi ve kurulum kaynağı; Kur sayfasından kurulum sayfayı değiştirmez

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 5: Ortak görseller ve adım listesi

**Files:**
- Create: `Kopru/Views/CatalogVisuals.swift`
- Create: `Kopru/Views/InstallStepsList.swift`
- Modify: `Kopru/Views/InstallProgressView.swift`
- Modify: `Kopru/AppModel.swift` (tarif simgesi)

**Interfaces:**
- Consumes: `CatalogEntry`, `RecipeRating`, `UpcomingStatus`, `InstallSource`, `RecipeCatalog.iconURL(for:)`.
- Produces:
  - `enum BadgeTone { case green, teal, orange, red, gray; var color: Color }`
  - `RecipeRating.tone`, `UpcomingStatus.tone`
  - `CatalogEntry.badge: (label: String, tone: BadgeTone)`, `CatalogEntry.verdictText: String?`, `CatalogEntry.installSource: InstallSource?`
  - `struct RatingBadge: View { init(label: String, tone: BadgeTone) }`
  - `struct EntryIcon: View { init(entry: CatalogEntry, size: CGFloat = 42) }`
  - `struct InstallStepsList: View { init(progress: InstallProgress) }`
  - `AppModel.recipeIcon(for: CatalogEntry) -> NSImage?`

- [ ] **Adım 1: Tarif simgesini modele ekle**

`Kopru/AppModel.swift` içinde `iconCache` satırının altına ekle:

```swift
    /// Tarif simgeleri (RecipeFiles/<id>/icon.png); bir kez okunur.
    @ObservationIgnored private var recipeIconCache: [String: NSImage] = [:]
```

`icon(for:in:)` fonksiyonunun altına ekle:

```swift
    /// Kartın tarif simgesi; "Yakında" girdilerinde ve simgesi olmayan tarifte nil.
    func recipeIcon(for entry: CatalogEntry) -> NSImage? {
        guard case let .recipe(recipe) = entry else { return nil }
        if let cached = recipeIconCache[recipe.id] { return cached }
        guard let url = catalog.iconURL(for: recipe.id), let image = NSImage(contentsOf: url) else { return nil }
        recipeIconCache[recipe.id] = image
        return image
    }
```

- [ ] **Adım 2: Görselleri yaz**

`Kopru/Views/CatalogVisuals.swift`:

```swift
import KopruCore
import SwiftUI

/// Rozet rengi; anlam taşır (yeşil sorunsuz … gri test ediliyor).
enum BadgeTone {
    case green, teal, orange, red, gray

    var color: Color {
        switch self {
        case .green: .green
        case .teal: .teal
        case .orange: .orange
        case .red: .red
        case .gray: .secondary
        }
    }
}

extension RecipeRating {
    var tone: BadgeTone {
        switch self {
        case .perfect: .green
        case .works: .teal
        case .partial: .orange
        case .broken: .red
        }
    }
}

extension UpcomingStatus {
    var tone: BadgeTone {
        switch self {
        case .testing: .gray
        case .broken: .red
        }
    }
}

extension CatalogEntry {
    /// Kartta ve panelde gösterilen uyumluluk etiketi.
    var badge: (label: String, tone: BadgeTone) {
        switch self {
        case let .recipe(recipe): (recipe.rating.label, recipe.rating.tone)
        case let .upcoming(program): (program.status.label, program.status.tone)
        }
    }

    /// Paneldeki açıklama cümlesi.
    var verdictText: String? {
        switch self {
        case let .recipe(recipe):
            recipe.verdict
        case let .upcoming(program):
            switch program.status {
            case .testing: "Bu program için kurulum tarifi hazırlanıyor."
            case .broken: program.note ?? "Bu program şu an Köprü'de açılmıyor."
            }
        }
    }

    /// Bu karta ait kurulumun kaynağı; yalnızca tarifler kurulur.
    var installSource: InstallSource? {
        if case let .recipe(recipe) = self { .recipe(recipe.id) } else { nil }
    }
}

/// Renkli nokta + metin kapsülü.
struct RatingBadge: View {
    let label: String
    let tone: BadgeTone

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tone.color).frame(width: 6, height: 6)
            Text(label)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tone.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(tone.color.opacity(0.14), in: Capsule())
    }
}

/// Kart ve panel simgesi: tarifin icon.png'si, yoksa kategori simgesi.
struct EntryIcon: View {
    @Environment(AppModel.self) private var model
    let entry: CatalogEntry
    var size: CGFloat = 42

    var body: some View {
        Group {
            if let image = model.recipeIcon(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: entry.category.symbolName)
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: size * 0.24))
            }
        }
        .frame(width: size, height: size)
    }
}
```

- [ ] **Adım 3: Adım listesini ayır**

`Kopru/Views/InstallStepsList.swift`:

```swift
import KopruCore
import SwiftUI

/// Kurulum adımları: bitti ✓, sürüyor (dönen), başarısız ✕, bekliyor ○; indirmede yüzde.
struct InstallStepsList: View {
    let progress: InstallProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(progress.steps, id: \.self) { step in
                HStack(spacing: 10) {
                    icon(for: step).frame(width: 18)
                    Text(step.title)
                    if step == .downloading, progress.current == .downloading, let fraction = progress.fraction {
                        ProgressView(value: fraction).frame(maxWidth: 140)
                        Text(fraction, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func icon(for step: InstallStep) -> some View {
        if progress.failedStep == step {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        } else if progress.done.contains(step) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else if progress.current == step {
            ProgressView().controlSize(.small)
        } else {
            Image(systemName: "circle").foregroundStyle(.tertiary)
        }
    }
}
```

`Kopru/Views/InstallProgressView.swift` içinde `VStack(alignment: .leading, spacing: 10) { ForEach(progress.steps …) { … } }` bloğunun tamamını şu tek satırla değiştir ve dosyadaki `icon(for:in:)` fonksiyonunu sil:

```swift
            InstallStepsList(progress: progress)
```

Yapının üstündeki açıklamayı şöyle yap:

```swift
/// Sheet olarak adım adım kurulum ilerlemesi; durumu `model.install`'dan okur.
```

- [ ] **Adım 4: Derle**

Çalıştır: `xcodegen generate && xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build -quiet build`
Beklenen: Hatasız.

- [ ] **Adım 5: Commit**

```bash
git add Kopru/Views/CatalogVisuals.swift Kopru/Views/InstallStepsList.swift Kopru/Views/InstallProgressView.swift Kopru/AppModel.swift
git commit -m "Uygulama: uyumluluk rozeti, kart simgesi ve ortak adım listesi

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 6: Kur sayfası, kartlar ve tarif paneli

**Files:**
- Create: `Kopru/Views/CatalogCard.swift`
- Create: `Kopru/Views/InstallInspector.swift`
- Create: `Kopru/Views/InstallPage.swift`
- Modify: `Kopru/Views/BottleSidebar.swift`
- Modify: `Kopru/Views/ContentView.swift`
- Modify: `Kopru/KopruApp.swift`

**Interfaces:**
- Consumes: Görev 4 (`selection`, `selectedEntryID`, `selectEntry`, `installedBottle`, `launchRecipe`, `isInstallRunning`, `closeInstallPanel`, `showRunningInstall`, `showInstallPage`, `isBottlePage`), Görev 5 (`RatingBadge`, `EntryIcon`, `InstallStepsList`, `CatalogEntry.badge/verdictText/installSource`).
- Produces:
  - `extension EnvironmentValues { var isInstallSearchActive: Bool }` (Görev 8 doldurur)
  - `extension View { func defaultActionUnlessSearching() -> some View }`
  - `struct PanelSectionTitle: View { init(_ title: LocalizedStringKey) }`
  - `struct InstallProgressPanel: View { init(progress: InstallProgress) }`
  - `struct RunningInstallNotice: View`
  - `struct InstallInspector: View`, `struct InstallPage: View`, `struct CatalogCard: View`

Bu görevden sonra tarifler sayfadan kurulur. Listede olmayan program sürükle-bırakta hâlâ eski `InstallSheet` ile açılır (Görev 7 taşır). "Yakında" kartlarının panelinde henüz düğme yok (Görev 7).

- [ ] **Adım 1: Kartı yaz**

`Kopru/Views/CatalogCard.swift`:

```swift
import KopruCore
import SwiftUI

/// Kur sayfasındaki program kartı.
struct CatalogCard: View {
    @Environment(AppModel.self) private var model
    let entry: CatalogEntry
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            EntryIcon(entry: entry)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(entry.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                status.padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.1)) : AnyShapeStyle(.background),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.separator),
                              lineWidth: isSelected ? 1.5 : 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var status: some View {
        if let progress = model.install, progress.source == entry.installSource, !progress.finished {
            if progress.failedStep != nil {
                RatingBadge(label: "Kurulamadı", tone: .red)
            } else {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    if progress.current == .downloading, let fraction = progress.fraction {
                        Text("Kuruluyor \(fraction, format: .percent.precision(.fractionLength(0)))")
                    } else {
                        Text("Kuruluyor")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else if let bottle = model.installedBottle(for: entry) {
            HStack {
                Label("Kurulu", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Aç") { model.launchRecipe(in: bottle) }
                    .controlSize(.small)
            }
        } else {
            RatingBadge(label: entry.badge.label, tone: entry.badge.tone)
        }
    }
}
```

- [ ] **Adım 2: Sağ paneli yaz**

`Kopru/Views/InstallInspector.swift`:

```swift
import KopruCore
import SwiftUI

extension EnvironmentValues {
    /// Kur sayfasının arama alanı odakta mı? Odaktayken Return kurulum başlatmasın.
    @Entry var isInstallSearchActive = false
}

/// Kur/Aç düğmelerinin Return kısayolu; arama alanı odaktayken kapalı.
private struct DefaultActionUnlessSearching: ViewModifier {
    @Environment(\.isInstallSearchActive) private var searching

    func body(content: Content) -> some View {
        content.keyboardShortcut(searching ? nil : .defaultAction)
    }
}

extension View {
    func defaultActionUnlessSearching() -> some View {
        modifier(DefaultActionUnlessSearching())
    }
}

/// Panel içindeki küçük bölüm başlığı.
struct PanelSectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .padding(.bottom, 7)
    }
}

/// Kur sayfasının sağ paneli.
struct InstallInspector: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let entry = model.selectedEntry {
            EntryDetail(entry: entry).id(entry.id)
        } else {
            ContentUnavailableView("Bir program seç", systemImage: "square.grid.2x2",
                                   description: Text("Ayrıntılar ve kurulum burada görünür."))
        }
    }
}

/// Seçili kartın ayrıntısı; altta eylemler.
private struct EntryDetail: View {
    let entry: CatalogEntry

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    verdict.padding(.top, 14)
                    if case let .recipe(recipe) = entry {
                        RecipeFacts(recipe: recipe)
                    }
                }
                .padding(EdgeInsets(top: 26, leading: 22, bottom: 16, trailing: 22))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            EntryActions(entry: entry)
                .padding(EdgeInsets(top: 14, leading: 22, bottom: 18, trailing: 22))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            EntryIcon(entry: entry, size: 56)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name).font(.title3.bold())
                Text([entry.publisher, entry.summary].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var verdict: some View {
        VStack(alignment: .leading, spacing: 6) {
            RatingBadge(label: entry.badge.label, tone: entry.badge.tone)
            if let text = entry.verdictText {
                Text(text).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(entry.badge.tone.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Tarifin test bilgisi, Köprü'nün yaptığı ayarlar ve indirme notu.
private struct RecipeFacts: View {
    let recipe: Recipe

    var body: some View {
        if let tested = recipe.testedOn {
            Text("Son test: \(tested.summary)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        if let highlights = recipe.highlights, !highlights.isEmpty {
            PanelSectionTitle("Köprü senin yerine ayarlar")
            ForEach(highlights, id: \.self) { highlight in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(highlight.title)
                        Text(highlight.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        if let note = recipe.downloadNote {
            PanelSectionTitle("İndirilecek")
            Text(note).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Panelin altındaki eylemler.
private struct EntryActions: View {
    @Environment(AppModel.self) private var model
    let entry: CatalogEntry
    @State private var bottleName: String

    init(entry: CatalogEntry) {
        self.entry = entry
        let name = if case let .recipe(recipe) = entry { recipe.bottle.defaultName } else { entry.name }
        _bottleName = State(initialValue: name)
    }

    var body: some View {
        switch entry {
        case let .recipe(recipe):
            recipeActions(recipe)
        case .upcoming:
            EmptyView()
        }
    }

    @ViewBuilder
    private func recipeActions(_ recipe: Recipe) -> some View {
        if let progress = model.install, progress.source == .recipe(recipe.id) {
            InstallProgressPanel(progress: progress)
        } else if let bottle = model.installedBottle(for: entry) {
            VStack(alignment: .leading, spacing: 8) {
                Text("“\(bottle.info.name)” bottle'ında kurulu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Bottle'a git") { model.selection = .bottle(bottle.id) }
                    Spacer()
                    Button("Aç") { model.launchRecipe(in: bottle) }
                        .defaultActionUnlessSearching()
                }
            }
        } else if recipe.rating == .broken {
            EmptyView()
        } else if model.isInstallRunning {
            RunningInstallNotice()
        } else {
            installForm(recipe)
        }
    }

    private func installForm(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Bottle adı").font(.caption).foregroundStyle(.secondary)
            TextField("Bottle adı", text: $bottleName).labelsHidden()
            if !bottleName.trimmingCharacters(in: .whitespaces).isEmpty && !model.isNameAvailable(bottleName) {
                Text("Bu adla bir bottle var.").font(.caption).foregroundStyle(.red)
            }
            HStack {
                Text("İnternet gerekli").font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button("Kur") { model.installRecipe(recipe, bottleName: bottleName) }
                    .defaultActionUnlessSearching()
                    .disabled(!model.isNameAvailable(bottleName))
            }
            .padding(.top, 7)
        }
    }
}

/// Başka bir kurulum sürerken Kur düğmesinin yerine.
struct RunningInstallNotice: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack {
            Text("Önce süren kurulum bitsin.").foregroundStyle(.secondary)
            Spacer()
            Button("Göster") { model.showRunningInstall() }
        }
    }
}

/// Sağ paneldeki kurulum ilerlemesi: adımlar, hata ve bitiş düğmeleri.
struct InstallProgressPanel: View {
    @Environment(AppModel.self) private var model
    let progress: InstallProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InstallStepsList(progress: progress)
            if let message = progress.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if progress.failedStep != nil {
                failedActions
            } else if progress.finished, let bottle = progress.bottle {
                HStack {
                    Button("Bottle'a git") {
                        model.closeInstallPanel()
                        model.selection = .bottle(bottle.id)
                    }
                    Spacer()
                    if case .recipe = progress.source {
                        Button("Aç") { model.launchRecipe(in: bottle) }
                            .defaultActionUnlessSearching()
                    }
                }
            } else {
                Text("Bu sırada başka programlara göz atabilirsin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var failedActions: some View {
        if let bottle = progress.bottle {
            Button("Günlüğü göster") { model.openLog(model.logURL(for: bottle)) }
        }
        HStack {
            if progress.createsBottle, progress.bottle != nil {
                Button("Yarım bottle'ı sil", role: .destructive) { model.deleteFailedInstallBottle() }
            }
            Spacer()
            Button(progress.createsBottle && progress.bottle != nil ? "Tut ve kapat" : "Kapat") {
                model.closeInstallPanel()
            }
        }
    }
}
```

- [ ] **Adım 3: Sayfayı yaz**

`Kopru/Views/InstallPage.swift`:

```swift
import KopruCore
import SwiftUI

/// Kenar çubuğundaki "Program kur": arama, kategoriler, kartlar ve sağ panel.
struct InstallPage: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var category: RecipeCategory?
    @FocusState private var searchFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 10, alignment: .top)]

    var body: some View {
        let sections = model.catalog.sections(matching: query, category: category)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                filterRow
                    .padding(.top, 14)
                    .padding(.bottom, 22)
                if sections.isEmpty {
                    emptyResult
                } else {
                    grid("Kurulmaya hazır", note: "Köprü ekibi test etti", entries: sections.ready)
                    grid("Yakında", note: "Test ediliyor", entries: sections.upcoming)
                }
            }
            .padding(EdgeInsets(top: 26, leading: 28, bottom: 28, trailing: 28))
        }
        .navigationTitle("Program kur")
        .inspector(isPresented: .constant(true)) {
            InstallInspector()
                .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
        }
        .onAppear {
            if model.selectedEntryID == nil, model.unlistedFile == nil {
                model.selectedEntryID = (sections.ready.first ?? sections.upcoming.first)?.id
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("Program kur").font(.largeTitle.bold())
            Spacer()
            searchField.frame(width: 280)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Program ara", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .help("Aramayı temizle")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }

    private var chips: some View {
        HStack(spacing: 6) {
            CategoryChip(title: "Tümü", count: model.catalog.count(in: nil), isOn: category == nil) {
                category = nil
            }
            ForEach(model.catalog.categories, id: \.self) { item in
                CategoryChip(title: item.label, count: model.catalog.count(in: item), isOn: category == item) {
                    category = item
                }
            }
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) { chips }
    }

    @ViewBuilder
    private func grid(_ title: LocalizedStringKey, note: LocalizedStringKey, entries: [CatalogEntry]) -> some View {
        if !entries.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.headline)
                Text(note).font(.callout).foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(entries) { entry in
                    CatalogCard(entry: entry,
                                isSelected: model.unlistedFile == nil && model.selectedEntryID == entry.id)
                        .onTapGesture(count: 2) { openIfInstalled(entry) }
                        .onTapGesture { model.selectEntry(entry.id) }
                }
            }
            .padding(.bottom, 26)
        }
    }

    private func openIfInstalled(_ entry: CatalogEntry) {
        model.selectEntry(entry.id)
        if let bottle = model.installedBottle(for: entry) { model.launchRecipe(in: bottle) }
    }

    private var emptyResult: some View {
        VStack(spacing: 6) {
            Text(query.isEmpty ? "Katalogda program yok" : "“\(query)” için hazır tarif yok")
                .font(.headline)
            Text("Kurulum dosyan varsa pencereye sürükle; Köprü onu yeni bir bottle'a kurar.")
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(24)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        }
    }
}

/// Kategori kapsülü; seçiliyken dolu.
private struct CategoryChip: View {
    let title: String
    let count: Int
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                Text(count, format: .number).opacity(0.6)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .foregroundStyle(isOn ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
            .background(isOn ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Adım 4: Kenar çubuğuna "Program kur" satırını ekle**

`Kopru/Views/BottleSidebar.swift` içinde `List(selection: $model.selectedBottleID) {` satırından `Section("Bottle'lar") {` satırına kadar olan kısmı şununla değiştir:

```swift
        List(selection: $model.selection) {
            Label("Program kur", systemImage: "plus.circle")
                .tag(SidebarItem.install)
            Section("Bottle'lar") {
```

Aynı dosyada bottle satırındaki `.tag(bottle.id)` satırını `.tag(SidebarItem.bottle(bottle.id))` yap.

- [ ] **Adım 5: Ana pencereyi sayfalara bağla**

`Kopru/Views/ContentView.swift` dosyasının tamamı (bu görevde listede olmayan program hâlâ sürükle-bırak → `InstallSheet`):

```swift
import KopruCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var unlistedStart: InstallSheet.Start?
    @State private var showSettings = false
    @State private var pickExecutable = false
    @State private var executableToRun: URL?

    var body: some View {
        NavigationSplitView {
            BottleSidebar()
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            detail
        }
        .toolbar { toolbar }
        .onChange(of: model.selection) { model.rescan() }
        .dropDestination(for: URL.self) { urls, _ in
            guard model.isReady, let file = urls.first,
                  ["exe", "msi"].contains(file.pathExtension.lowercased()) else { return false }
            unlistedStart = .unlisted(file)
            return true
        }
        .sheet(item: $unlistedStart) { start in
            InstallSheet(start: start)
        }
        .sheet(item: progressBinding) { _ in
            InstallProgressView()
        }
        .sheet(isPresented: $showSettings) {
            if let bottle = model.selectedBottle {
                BottleSettingsSheet(bottle: bottle)
            }
        }
        .fileImporter(isPresented: $pickExecutable, allowedContentTypes: UTType.windowsInstallers) { result in
            if case let .success(url) = result { executableToRun = url }
        }
        .fileDialogDefaultDirectory(model.selectedBottle?.driveC)
        .confirmationDialog("Program çalıştırılsın mı?",
                            isPresented: Binding(get: { executableToRun != nil }, set: { if !$0 { executableToRun = nil } }),
                            presenting: executableToRun) { url in
            Button("Çalıştır") { model.runExecutable(url, pin: false) }
            Button("Çalıştır ve listeye ekle") { model.runExecutable(url, pin: true) }
            Button("Vazgeç", role: .cancel) {}
        } message: { url in
            Text(url.lastPathComponent)
        }
        .alert(model.alert?.title ?? "",
               isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } }),
               presenting: model.alert) { alert in
            if let log = alert.logURL {
                Button("Günlüğü Göster") { model.openLog(log) }
            }
            Button("Tamam", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }

    /// Tarif kurulumları Kur sayfasının panelinde; diğerleri (listede olmayan, boş bottle) bu sheet'te.
    private var progressBinding: Binding<InstallProgress?> {
        Binding(get: {
                    guard unlistedStart == nil, let progress = model.install else { return nil }
                    if case .recipe = progress.source { return nil }
                    return progress
                },
                set: { if $0 == nil { model.install = nil } })
    }

    @ViewBuilder
    private var detail: some View {
        if let problem = model.startupProblem {
            StartupProblemView(problem: problem)
        } else if model.isBottlePage, let bottle = model.selectedBottle {
            ProgramGrid(bottle: bottle)
        } else {
            InstallPage()
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if model.isBottlePage {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.showInstallPage() } label: { Label("Kur", systemImage: "plus.circle") }
                    .disabled(!model.isReady)
                Button { model.openDriveC() } label: { Label("C: Sürücüsü", systemImage: "internaldrive") }
                    .disabled(model.selectedBottle == nil)
                Button { pickExecutable = true } label: { Label("Program Çalıştır…", systemImage: "play") }
                    .disabled(model.selectedBottle == nil || !model.isReady)
                Button { model.stopSelected() } label: { Label("Durdur", systemImage: "stop.circle") }
                    .disabled(model.selectedBottle == nil || !model.isReady)
                Button { showSettings = true } label: { Label("Ayarlar", systemImage: "gearshape") }
                    .disabled(model.selectedBottle == nil)
            }
        }
    }
}
```

- [ ] **Adım 6: Pencerenin en küçük boyutunu büyüt**

`Kopru/KopruApp.swift` içinde `.frame(minWidth: 780, minHeight: 480)` → `.frame(minWidth: 1040, minHeight: 560)`.

- [ ] **Adım 7: Derle ve aç**

Çalıştır: `xcodegen generate && xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build -quiet build && open build/Build/Products/Debug/Kopru.app`
Beklenen: Hatasız derlenir, uygulama açılır.

- [ ] **Adım 8: Umut'un kontrolü**

Umut'a şu listeyi ver, cevabını bekle:
1. Kenar çubuğunun en üstünde "Program kur" var; tıklayınca sayfa ve sağ panel açılıyor.
2. Steam "Kurulmaya hazır"da, simgesiyle ve "Çalışıyor" (camgöbeği) etiketiyle; Steam kuruluysa "✓ Kurulu" + **Aç**.
3. "Yakında"da Epic (kırmızı) ve test edilen 8 program (gri) var.
4. Arama ("valve", "baslaticisi") ve kategori kapsülleri süzüyor.
5. Bir bottle sayfasında araç çubuğundaki **Kur** bu sayfaya getiriyor.
6. (Steam kurulu değilse ya da ikinci adla) **Kur** → ilerleme sağ panelde, bu sırada başka kart seçilebiliyor.
Bir madde tutmuyorsa düzelt, yeniden derle, tekrar sor.

- [ ] **Adım 9: Commit**

```bash
git add Kopru/Views/CatalogCard.swift Kopru/Views/InstallInspector.swift Kopru/Views/InstallPage.swift Kopru/Views/BottleSidebar.swift Kopru/Views/ContentView.swift Kopru/KopruApp.swift
git commit -m "Uygulama: Program kur sayfası, kartlar ve tarif paneli; ilerleme panelde

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 7: Listede olmayan program, Yakında eylemleri, sürükle-bırak katmanı

**Files:**
- Create: `Kopru/Views/WindowsInstallers.swift`
- Create: `Kopru/Views/UnlistedDetail.swift`
- Create: `Kopru/Views/DropOverlay.swift`
- Delete: `Kopru/Views/InstallSheet.swift`
- Modify: `Kopru/Views/InstallInspector.swift`, `Kopru/Views/InstallPage.swift`, `Kopru/Views/ContentView.swift`, `Kopru/AppModel.swift`
- Modify: `KopruCore/Sources/KopruCore/RecipeCatalog.swift`, `KopruCore/Tests/KopruCoreTests/RecipeCatalogTests.swift` (`search` silinir)

**Interfaces:**
- Consumes: Görev 4 (`showInstallPage(unlisted:)`, `unlistedFile`, `unlistedDefaultBottleID`, `installUnlisted`), Görev 6 (`PanelSectionTitle`, `InstallProgressPanel`, `RunningInstallNotice`, `defaultActionUnlessSearching`).
- Produces: `AppModel.isPickingInstaller: Bool`, `struct UnlistedDetail: View { init(file: URL, defaultBottleID: Bottle.ID?) }`, `struct DropOverlay: View`, `UTType.windowsInstallers` (yeni dosyada).

- [ ] **Adım 1: UTType uzantısını taşı, eski pencereyi sil**

`Kopru/Views/WindowsInstallers.swift`:

```swift
import UniformTypeIdentifiers

extension UTType {
    /// Windows kurulum dosyaları (.exe, .msi).
    static let windowsInstallers: [UTType] = ["exe", "msi"].compactMap { UTType(filenameExtension: $0) }
}
```

Çalıştır: `git rm Kopru/Views/InstallSheet.swift`

`KopruCore/Sources/KopruCore/RecipeCatalog.swift` içinden `search(_:)` fonksiyonunu (açıklamasıyla) sil. `KopruCore/Tests/KopruCoreTests/RecipeCatalogTests.swift` içinden `searchIsCaseAndDiacriticInsensitive` testini sil (arama artık `sections` testlerinde).

- [ ] **Adım 2: Dosya seçici bayrağını ekle**

`Kopru/AppModel.swift` içinde `unlistedDefaultBottleID` satırının altına ekle:

```swift
    /// Kur sayfasının kurulum dosyası seçicisi açık mı ("Dosya seç…", "Yine de dene…").
    var isPickingInstaller = false
```

- [ ] **Adım 3: Listede olmayan dosya panelini yaz**

`Kopru/Views/UnlistedDetail.swift`:

```swift
import KopruCore
import SwiftUI

/// Listede olmayan kurulum dosyası: nereye kurulacağı ve ilerleme.
struct UnlistedDetail: View {
    @Environment(AppModel.self) private var model
    let file: URL
    private let fileSize: String
    @State private var targetBottleID: Bottle.ID?
    @State private var bottleName: String

    init(file: URL, defaultBottleID: Bottle.ID?) {
        self.file = file
        let bytes = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        fileSize = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        _targetBottleID = State(initialValue: defaultBottleID)
        _bottleName = State(initialValue: file.deletingPathExtension().lastPathComponent)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 13) {
                        Image(systemName: "doc")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                            .frame(width: 56, height: 56)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(file.lastPathComponent).font(.title3.bold()).lineLimit(2)
                            Text("Listede olmayan program · \(fileSize)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Bu program için Köprü'de hazır ayar yok; genel Windows 10 ayarlarıyla kurulur.")
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 14)
                    PanelSectionTitle("Ne olacak")
                    step(1, "Windows kurulum penceresi açılır", detail: "Kurulumu oradan bitirirsin")
                    step(2, "Programlar listeye eklenir", detail: "Kurulum penceresi kapanınca")
                }
                .padding(EdgeInsets(top: 26, leading: 22, bottom: 16, trailing: 22))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
                .padding(EdgeInsets(top: 14, leading: 22, bottom: 18, trailing: 22))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func step(_ number: Int, _ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(number, format: .number)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(.quaternary, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var footer: some View {
        if let progress = model.install, progress.source == .unlisted(file) {
            InstallProgressPanel(progress: progress)
        } else if model.isInstallRunning {
            RunningInstallNotice()
        } else {
            VStack(alignment: .leading, spacing: 5) {
                Picker("Nereye kurulsun", selection: $targetBottleID) {
                    Text("Yeni bottle").tag(Bottle.ID?.none)
                    ForEach(model.bottles) { bottle in
                        Text(bottle.info.name).tag(Bottle.ID?.some(bottle.id))
                    }
                }
                if targetBottleID == nil {
                    Text("Bottle adı").font(.caption).foregroundStyle(.secondary).padding(.top, 6)
                    TextField("Bottle adı", text: $bottleName).labelsHidden()
                    if !bottleName.trimmingCharacters(in: .whitespaces).isEmpty && !model.isNameAvailable(bottleName) {
                        Text("Bu adla bir bottle var.").font(.caption).foregroundStyle(.red)
                    }
                }
                HStack {
                    Button("Vazgeç") { model.unlistedFile = nil }
                    Spacer()
                    Button("Kur") { install() }
                        .defaultActionUnlessSearching()
                        .disabled(targetBottleID == nil && !model.isNameAvailable(bottleName))
                }
                .padding(.top, 7)
            }
        }
    }

    private func install() {
        let existing = targetBottleID.flatMap { id in model.bottles.first { $0.id == id } }
        model.installUnlisted(file: file, target: existing.map { .existing($0) } ?? .newBottle(bottleName))
    }
}
```

- [ ] **Adım 4: Paneli listede olmayan dosyaya ve Yakında eylemlerine bağla**

`Kopru/Views/InstallInspector.swift` içinde `InstallInspector.body`'yi şununla değiştir:

```swift
    var body: some View {
        if let file = model.unlistedFile {
            UnlistedDetail(file: file, defaultBottleID: model.unlistedDefaultBottleID).id(file)
        } else if let entry = model.selectedEntry {
            EntryDetail(entry: entry).id(entry.id)
        } else {
            ContentUnavailableView("Bir program seç", systemImage: "square.grid.2x2",
                                   description: Text("Ayrıntılar ve kurulum burada görünür."))
        }
    }
```

`EntryActions.body` içindeki `case .upcoming: EmptyView()` dalını şununla değiştir:

```swift
        case let .upcoming(program):
            TryAnywayActions(broken: program.status == .broken)
```

`recipeActions` içindeki `} else if recipe.rating == .broken { EmptyView()` dalını şununla değiştir:

```swift
        } else if recipe.rating == .broken {
            TryAnywayActions(broken: true)
```

Dosyanın sonuna ekle:

```swift
/// Hazır olmayan programda: kurulum dosyasıyla genel ayarlarla deneme.
private struct TryAnywayActions: View {
    @Environment(AppModel.self) private var model
    let broken: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(broken
                 ? "Kurulum dosyasıyla genel ayarlarla yine de deneyebilirsin; sorun çıkarsa günlük dosyası yardımcı olur."
                 : "Kurulum dosyan varsa hazır tarifi beklemeden genel ayarlarla deneyebilirsin.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(broken ? "Yine de dene…" : "Dosya seç…") { model.isPickingInstaller = true }
        }
    }
}
```

- [ ] **Adım 5: Sayfaya "Listede yok mu?" bağlantısını ve dosya seçiciyi ekle**

`Kopru/Views/InstallPage.swift` içinde `filterRow`'u şununla değiştir:

```swift
    private var filterRow: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) { chips }
            HStack(spacing: 4) {
                Text("Listede yok mu?").foregroundStyle(.secondary)
                Button("Dosya seç…") { model.isPickingInstaller = true }
                    .buttonStyle(.link)
            }
            .fixedSize()
            .help("Kurulum dosyasını (.exe, .msi) pencereye de sürükleyebilirsin")
        }
    }
```

`emptyResult` içindeki ikinci `Text(...)` satırının altına ekle:

```swift
            Button("Dosya seç…") { model.isPickingInstaller = true }
                .padding(.top, 6)
```

`body` içinde `let sections = …` satırının üstüne `@Bindable var model = model` ekle ve `.onAppear { … }` bloğunun altına:

```swift
        .fileImporter(isPresented: $model.isPickingInstaller, allowedContentTypes: UTType.windowsInstallers) { result in
            if case let .success(url) = result { model.showInstallPage(unlisted: url) }
        }
```

Dosyanın başına `import UniformTypeIdentifiers` ekle.

- [ ] **Adım 6: Sürükle-bırak katmanını yaz**

`Kopru/Views/DropOverlay.swift`:

```swift
import SwiftUI

/// Pencereye kurulum dosyası sürüklenirken detay sütununu kaplayan katman.
struct DropOverlay: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tint)
            Text("Bırak, kuralım").font(.title3.bold())
            Text(".exe ve .msi kurulum dosyaları").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(12)
        }
        .allowsHitTesting(false)
    }
}
```

- [ ] **Adım 7: Ana pencerede bırakmayı Kur sayfasına yönlendir**

`Kopru/Views/ContentView.swift` içinde:

1. `@State private var unlistedStart: InstallSheet.Start?` satırını `@State private var isDropTargeted = false` yap.
2. `} detail: { detail }` kısmını şununla değiştir:

```swift
        } detail: {
            detail
                .dropDestination(for: URL.self) { urls, _ in
                    handleDrop(urls)
                } isTargeted: { isDropTargeted = $0 }
                .overlay {
                    if isDropTargeted { DropOverlay() }
                }
        }
```

3. Pencere düzeyindeki `.dropDestination(for: URL.self) { … }` bloğunu ve `.sheet(item: $unlistedStart) { … }` bloğunu sil.
4. `progressBinding`'i şununla değiştir:

```swift
    /// Kur sayfasındaki kurulumlar sağ panelde; yalnızca boş bottle oluşturma sheet'te görünür.
    private var progressBinding: Binding<InstallProgress?> {
        Binding(get: { model.install?.source == .emptyBottle ? model.install : nil },
                set: { if $0 == nil { model.install = nil } })
    }

    private func handleDrop(_ urls: [URL]) -> Bool {
        guard model.isReady else { return false }
        guard let file = urls.first(where: { ["exe", "msi"].contains($0.pathExtension.lowercased()) }) else {
            model.alert = AppAlert(title: "Bu dosya kurulamaz",
                                   message: "Yalnızca .exe ve .msi kurulum dosyaları kurulabilir.")
            return false
        }
        model.showInstallPage(unlisted: file)
        return true
    }
```

- [ ] **Adım 8: Test ve derle**

Çalıştır: `cd KopruCore && swift test`
Beklenen: Hepsi geçer.

Çalıştır: `grep -rn "InstallSheet" Kopru/ ; xcodegen generate && xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build -quiet build && open build/Build/Products/Debug/Kopru.app`
Beklenen: `grep` hiçbir şey bulmaz; derleme hatasız.

- [ ] **Adım 9: Umut'un kontrolü**

1. "Listede yok mu? **Dosya seç…**" → `~/WineBottles/indirilenler/notepadpp/npp.8.9.9.1.Installer.x64.exe` seç → panel dosyayı, boyutunu, "Nereye kurulsun"u gösteriyor. **Vazgeç** paneli kart seçimine döndürüyor.
2. Aynı dosyayı Finder'dan pencereye sürükle → "Bırak, kuralım" katmanı; bırakınca aynı panel. Bir bottle sayfasındayken bırakılırsa "Nereye kurulsun" o bottle'ı öneriyor.
3. Bir `.zip` ya da `.pdf` bırak → "Yalnızca .exe ve .msi kurulum dosyaları kurulabilir."
4. GOG Galaxy kartı → panelde "Dosya seç…"; Epic kartı → kırmızı not ve "Yine de dene…".
5. Notepad++ kurulum dosyasını yeni bir bottle'a kur → Windows kurulum penceresi açılıyor, ilerleme panelde; bitince **Bottle'a git** bottle'a götürüyor.
6. Kenar çubuğu "+" → "Boş Bottle…" hâlâ eski sheet'le çalışıyor.

- [ ] **Adım 10: Commit**

```bash
git add -A Kopru/Views Kopru/AppModel.swift KopruCore/Sources/KopruCore/RecipeCatalog.swift KopruCore/Tests/KopruCoreTests/RecipeCatalogTests.swift
git commit -m "Uygulama: listede olmayan program panelde, Yakında eylemleri, sürükle-bırak katmanı; eski Kur penceresi kalktı

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 8: Klavye ve son dokunuşlar

**Files:**
- Modify: `Kopru/AppModel.swift`, `Kopru/KopruApp.swift`, `Kopru/Views/InstallPage.swift`, `Kopru/Views/BottleSidebar.swift`

**Interfaces:**
- Consumes: Görev 6 (`isInstallSearchActive`), Görev 5 (`recipeIcon(for:)`).
- Produces: `AppModel.wantsSearchFocus: Bool`, `AppModel.focusSearch()`, `AppModel.recipeIcon(forBottle:) -> NSImage?`; Düzen menüsünde "Programlarda Ara" (⌘F).

- [ ] **Adım 1: Modele arama odağı ve bottle simgesi**

`Kopru/AppModel.swift` içinde `isPickingInstaller` satırının altına ekle:

```swift
    /// ⌘F: Kur sayfası açılınca arama alanı odak alsın.
    var wantsSearchFocus = false

    func focusSearch() {
        selection = .install
        wantsSearchFocus = true
    }
```

`recipeIcon(for:)` fonksiyonunun altına ekle:

```swift
    /// Kenar çubuğunda tarife bağlı bottle'ın simgesi.
    func recipeIcon(forBottle bottle: Bottle) -> NSImage? {
        recipe(for: bottle).flatMap { recipeIcon(for: .recipe($0)) }
    }
```

- [ ] **Adım 2: ⌘F komutu**

`Kopru/KopruApp.swift` içinde `WindowGroup("Köprü") { … }` bloğunun kapanışından sonra ekle:

```swift
        .commands {
            // Düzen menüsündeki metin "Bul" grubu yerine: ⌘F Kur sayfasında arar.
            CommandGroup(replacing: .textEditing) {
                Button("Programlarda Ara") { model.focusSearch() }
                    .keyboardShortcut("f")
            }
        }
```

- [ ] **Adım 3: Arama alanında ⌘F ipucu, Esc ve Return**

`Kopru/Views/InstallPage.swift` içinde `searchField`'ı şununla değiştir:

```swift
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Program ara", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit(selectFirstResult)
                .onExitCommand { query = "" }
            if query.isEmpty {
                Text("⌘F").font(.caption).foregroundStyle(.tertiary)
            } else {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .help("Aramayı temizle")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Return: yalnızca ilk sonucu seçer; kurulum başlatmaz.
    private func selectFirstResult() {
        let sections = model.catalog.sections(matching: query, category: category)
        if let first = sections.ready.first ?? sections.upcoming.first { model.selectEntry(first.id) }
        searchFocused = false
    }
```

`body` içinde `InstallInspector()` satırını şununla değiştir:

```swift
            InstallInspector()
                .environment(\.isInstallSearchActive, searchFocused)
```

`.navigationTitle("Program kur")` satırının altına ekle:

```swift
        .toolbar(removing: .title)
        .task(id: model.wantsSearchFocus) {
            guard model.wantsSearchFocus else { return }
            // Sayfa yeni açıldıysa alan odak alabilsin diye bir an bekle.
            try? await Task.sleep(for: .milliseconds(50))
            searchFocused = true
            model.wantsSearchFocus = false
        }
```

- [ ] **Adım 4: Kenar çubuğunda tarif simgesi**

`Kopru/Views/BottleSidebar.swift` içinde `Label(bottle.info.name, systemImage: "shippingbox")` satırını şununla değiştir:

```swift
                        Label {
                            Text(bottle.info.name)
                        } icon: {
                            if let image = model.recipeIcon(forBottle: bottle) {
                                Image(nsImage: image).resizable().frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "shippingbox")
                            }
                        }
```

- [ ] **Adım 5: Derle ve aç**

Çalıştır: `xcodegen generate && xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build -quiet build && open build/Build/Products/Debug/Kopru.app`
Beklenen: Hatasız.

- [ ] **Adım 6: Umut'un kontrolü**

1. Bir bottle sayfasındayken ⌘F → Kur sayfası açılıp arama alanı odak alıyor.
2. "note" yaz, Return → Notepad++ (ya da ilk sonuç) seçiliyor, **kurulum başlamıyor**. Esc aramayı temizliyor.
3. Aramadan çıkınca (kartı tıkla) Return panelin **Kur**/**Aç** düğmesine basıyor.
4. Araç çubuğunda "Program kur" başlığı yinelenmiyor; Mission Control'de pencere adı görünüyor.
5. Kenar çubuğunda Steam bottle'ı Steam simgesiyle görünüyor.
6. Açık ve koyu temada rozet renkleri ve kartlar okunuyor (Sistem Ayarları → Görünüm).

- [ ] **Adım 7: Commit**

```bash
git add Kopru/AppModel.swift Kopru/KopruApp.swift Kopru/Views/InstallPage.swift Kopru/Views/BottleSidebar.swift
git commit -m "Uygulama: ⌘F ile arama, Return yalnızca seçer, Esc temizler; kenar çubuğunda tarif simgesi

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 9: Notepad++ ve WinRAR tarifleri

**Files:**
- Create: `Resources/Recipes/notepadpp.json`, `Resources/Recipes/winrar.json`
- Create: `Resources/RecipeFiles/notepadpp/icon.png`, `Resources/RecipeFiles/winrar/icon.png`

**Interfaces:**
- Consumes: Görev 1 tarif biçimi, Görev 3 `Tools/tarif-simgesi/simge.sh` ve `RepositoryCatalogTests` (yeni tarifleri kendiliğinden denetler).

Faz 0'da ikisi WineHQ 11.0'da çalıştı (Sheets satır 19–20). Köprü'nün motoru CX 26.3; tarif ancak Köprü'de testi geçerse kalır.

- [ ] **Adım 1: Kurulum dosyalarının sağlamasını doğrula**

Çalıştır:
```bash
curl -sL https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.9.9.1/npp.8.9.9.1.Installer.x64.exe | shasum -a 256
curl -sL https://www.rarlab.com/rar/winrar-x64-723tr.exe | shasum -a 256
```
Beklenen:
```
ce3267f5c4e7e42f847e00f4b20234da6150647203033cdde34a69593efc3152  -
b6b2dce0e529ccdfd2efcf3dc653a0144a6646081416a868f469bab587359f75  -
```
(Notepad++ değeri resmî `npp.8.9.9.1.checksums.sha256` dosyasıyla aynı.) Tutmazsa dur, Umut'a sor.

- [ ] **Adım 2: Tarifleri yaz**

`Resources/Recipes/notepadpp.json`:

```json
{
  "schema": 1,
  "id": "notepadpp",
  "name": "Notepad++",
  "publisher": "Don Ho",
  "summary": "Kod ve metin düzenleyici",
  "category": "office",
  "rating": "perfect",
  "verdict": "Kurulum, düzenleme ve Türkçe karakterler (ğüşıöç, € ve ₺) sorunsuz.",
  "testedOn": { "date": "2026-11-20", "hardware": "Apple M3", "macOS": "26.6" },
  "downloadNote": "7 MB",
  "bottle": {
    "defaultName": "Notepad++",
    "settings": { "msync": true, "virtualDesktop": { "mode": "off" }, "fpsHud": false }
  },
  "installer": {
    "url": "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.9.9.1/npp.8.9.9.1.Installer.x64.exe",
    "sha256": "ce3267f5c4e7e42f847e00f4b20234da6150647203033cdde34a69593efc3152",
    "fileName": "npp.8.9.9.1.Installer.x64.exe",
    "arguments": ["/S"]
  },
  "afterInstall": [],
  "beforeLaunch": [],
  "launch": {
    "name": "Notepad++",
    "windowsPath": "C:\\Program Files\\Notepad++\\notepad++.exe",
    "arguments": []
  },
  "detect": ["drive_c/Program Files/Notepad++/notepad++.exe"],
  "hideShortcuts": ["Notepad++.lnk"]
}
```

`Resources/Recipes/winrar.json`:

```json
{
  "schema": 1,
  "id": "winrar",
  "name": "WinRAR",
  "publisher": "win.rar GmbH",
  "summary": "Arşivleme, RAR ve ZIP açma",
  "category": "office",
  "rating": "perfect",
  "verdict": "Türkçe sürüm. Arşiv oluşturma, açma ve test çalışıyor.",
  "testedOn": { "date": "2026-11-20", "hardware": "Apple M3", "macOS": "26.6" },
  "downloadNote": "4 MB",
  "bottle": {
    "defaultName": "WinRAR",
    "settings": { "msync": true, "virtualDesktop": { "mode": "off" }, "fpsHud": false }
  },
  "installer": {
    "url": "https://www.rarlab.com/rar/winrar-x64-723tr.exe",
    "sha256": "b6b2dce0e529ccdfd2efcf3dc653a0144a6646081416a868f469bab587359f75",
    "fileName": "winrar-x64-723tr.exe",
    "arguments": ["/S"]
  },
  "afterInstall": [],
  "beforeLaunch": [],
  "launch": {
    "name": "WinRAR",
    "windowsPath": "C:\\Program Files\\WinRAR\\WinRAR.exe",
    "arguments": []
  },
  "detect": ["drive_c/Program Files/WinRAR/WinRAR.exe"],
  "hideShortcuts": ["WinRAR/WinRAR.lnk", "WinRAR/WinRAR yardımı.lnk", "WinRAR/Konsol RAR kılavuzu.lnk"]
}
```

(Kurulum yolları ve kısayol adları `~/WineBottles/faz0-temel`'deki gerçek kurulumdan alındı.)

- [ ] **Adım 3: Simgeleri üret**

Çalıştır:
```bash
Tools/tarif-simgesi/simge.sh "$HOME/WineBottles/faz0-temel/drive_c/Program Files/Notepad++/notepad++.exe" notepadpp
Tools/tarif-simgesi/simge.sh "$HOME/WineBottles/faz0-temel/drive_c/Program Files/WinRAR/WinRAR.exe" winrar
```
Beklenen: İkisinde de `pixelWidth: 256`.

- [ ] **Adım 4: Testler ve derleme**

Çalıştır: `cd KopruCore && swift test`
Beklenen: Hepsi geçer (`RepositoryCatalogTests` yeni tarifleri de denetler).

Çalıştır: `xcodegen generate && xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build -quiet build && open build/Build/Products/Debug/Kopru.app`

- [ ] **Adım 5: Umut Köprü'de test eder**

Umut'a: "Program kur → Notepad++ → **Kur**; bitince **Aç**. Türkçe karakterli bir metin yaz (ğüşıöç ĞÜŞİÖÇ € ₺), kaydet, yeniden aç. Sonra WinRAR → **Kur** → **Aç**; bir klasörü arşivle, arşivi test et, aç. Bottle sayfalarında yalnızca tarif başlatıcısı görünüyor mu (yinelenen kısayol yok)?"

- Geçtiyse: test başka bir gün yapıldıysa iki tarifte `testedOn.date`'i o günün tarihiyle (`yyyy-MM-dd`) güncelle.
- Biri geçmediyse: o tarifin JSON'unu ve `icon.png`'sini sil, `Resources/Catalog/upcoming.json`'a `"status": "broken"` ve kısa bir `note` ile girdi ekle (id aynı kalsın), `swift test` çalıştır; Sheets'teki satıra not düş.

- [ ] **Adım 6: Commit**

```bash
git add Resources/Recipes Resources/RecipeFiles Resources/Catalog/upcoming.json
git commit -m "Tarifler: Notepad++ ve WinRAR (Türkçe)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 10: Kabul testi ve belgeler

**Files:**
- Modify: `docs/superpowers/specs/2026-11-20-kur-ekrani-design.md` (Durum)
- Modify: `docs/superpowers/specs/2026-11-20-kopru-v0.1-design.md` (5. bölümdeki "Kur penceresi" satırı)
- Modify: `docs/superpowers/plans/2026-11-20-kur-ekrani.md` (Uygulama Notları)

- [ ] **Adım 1: Tüm testler**

Çalıştır: `cd KopruCore && swift test`
Beklenen: Hepsi geçer.

- [ ] **Adım 2: Spec başarı ölçütleri (Umut)**

Spec 1. bölümdeki 1–7. ölçütleri Umut'la tek tek geç. Ölçüt 5 (başarısız kurulum) **ofis ağında** Steam'i yeni bir adla kurarak denenir; panel "İndiriliyor" adımında ✕, açıklama, **Günlüğü göster**, **Yarım bottle'ı sil** / **Tut ve kapat** göstermeli. Ölçüt 4 (Steam başarılı kurulum) ev ağında. Tutmayan ölçüt için düzeltme yap, ilgili görevin kontrol listesini yeniden çalıştır.

- [ ] **Adım 3: Belgeleri güncelle**

- Spec başlığındaki `**Durum:** Taslak (gözden geçirme bekliyor)` → `**Durum:** Uygulandı (<bugünün tarihi>)`.
- v0.1 spec 5. bölümdeki `- **Kur penceresi** (sheet): …` satırını şununla değiştir: `- **Kur penceresi:** yerini Program kur sayfasına bıraktı; bkz. [2026-11-20-kur-ekrani-design.md](2026-11-20-kur-ekrani-design.md).`
- Bu planın sonuna `## Uygulama Notları` başlığıyla plandan sapmaları ve kabul testinde bulunanları yaz (yoksa "Sapma yok").

- [ ] **Adım 4: Commit**

```bash
git add docs/superpowers
git commit -m "Belgeler: Program kur ekranı uygulandı

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Adım 5: Dalı birleştirmeyi konuş**

superpowers:finishing-a-development-branch ile `gelistirme/kur-ekrani` dalının nereye birleşeceğini Umut'la konuş (v0.1 dalı henüz `main`'e birleşmedi).
