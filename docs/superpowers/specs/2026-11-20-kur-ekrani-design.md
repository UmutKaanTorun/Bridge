# Köprü — Program kur ekranı — Tasarım

- **Tarih:** 2026-11-20
- **Durum:** Uygulandı (2026-11-21; kurulum adımlarının elle testi ve Notepad++/WinRAR tarifleri bekliyor — bkz. planın Uygulama Notları)
- **Güncelleme:** 2026-11-21'de sayfa yalnızca oyun platformlarına ve tek tıkla kuruluma indirildi; sağ panel, kategoriler ve "Yakında" kalktı. Bkz. [`2026-11-21-platform-kur-design.md`](2026-11-21-platform-kur-design.md).
- **Bağlam:** v0.1'in "Kur penceresi" (500×420 sheet, düz liste) CrossOver'ın "Install a Windows Application" ekranından da zayıf. Bu tasarım onu ana pencerede bir sayfaya dönüştürür. Onaylanan görsel taslak: [`2026-11-20-kur-ekrani-taslak.html`](2026-11-20-kur-ekrani-taslak.html) (tarayıcıda açılır, tıklanabilir). Taslaktan farklar: "Haber ver" düğmesi ve süre tahmini ("Yaklaşık 4 dk") bu sürümde yok; harfli renkli simgeler yer tutucu; Enter aramada kurulum başlatmaz.
- **Ön koşul:** v0.1 dalındaki açık iş (exe simgeleri: `WindowsIcon.swift`, `ShortcutIcon.swift`, `AppModel`/`ProgramGrid` değişiklikleri) commit'lenmiş olmalı; bu iş aynı dosyalara dokunur.

## 1. Amaç

Kullanıcı bir Windows programını Köprü'ye kurmaya karar verirken üç soruya cevap bulsun:

1. **Çalışır mı?** Yıldız yerine sözlü bir uyumluluk etiketi, neyin çalışıp neyin çalışmadığını anlatan bir cümle ve son test bilgisi.
2. **Kurunca ne olacak?** Köprü'nün kendiliğinden yaptığı ayarlar ve ne kadar indirileceği, kurmadan önce görünür.
3. **Listede yoksa ne yapacağım?** Dosya seçme bağlantısı ve pencere genelinde sürükle-bırak her zaman elde.

### CrossOver'a göre farklar

| CrossOver | Köprü |
|---|---|
| "Install" kenar çubuğunun en altında, ayrı bir mod | "Program kur" kenar çubuğunun en üstünde, bottle'larla aynı listede |
| 5 yıldız + "Runs Great" (kullanıcı puanı gibi okunuyor) | Renkli sözlü etiket + açıklama cümlesi + son test tarihi ve donanım |
| Ayrıntı için ayrı sayfaya geçilir | Seçilen programın ayrıntısı sağ panelde; sayfa değişmez |
| Kurulu program da "Install" gösterir | Kurulu programın kartında "Kurulu" ve **Aç** |
| "Install an unlisted application" sağ üstte küçük bağlantı | Kategorilerin yanında bağlantı + pencere genelinde sürükle-bırak katmanı + boş aramada öneri |
| Kurulum modal pencerede | İlerleme sağ panelde; kurulum sürerken gezinmek serbest |
| Kategori yok | Oyun, İş ve muhasebe, Mühendislik, Ofis |

### Başarı ölçütleri

1. Kenar çubuğunda "Program kur" seçilince sayfa açılır; araç çubuğundaki **Kur** düğmesi ve boş durumdaki "Program Kur" düğmesi de aynı sayfaya götürür.
2. Steam ve Köprü'de testi geçen Notepad++ ve WinRAR tarifleri "Kurulmaya hazır" bölümünde, test listesindeki diğer programlar "Yakında" bölümünde görünür.
3. Arama ve kategori birlikte süzer; ⌘F aramaya odaklanır, Esc aramayı temizler; "notepad", "NOTEPAD", "valve" (yayıncı) bulunur, Türkçe klavyesiz yazım da eşleşir ("baslaticisi" ~ "başlatıcısı", "arsivleme" ~ "Arşivleme").
4. Steam sayfadan kurulur; ilerleme sağ panelde akar, bu sırada başka kartlar seçilebilir; bitince kart "Kurulu" olur, **Aç** Steam'i açar.
5. Ofis ağında (TLS denetimi) Steam kurulumu indirmede başarısız olur; panel adımı, açıklamayı, "Günlüğü göster"i ve yarım bottle seçeneklerini gösterir.
6. Bir `.exe` pencereye sürüklenince katman belirir; bırakınca sayfa "listede olmayan program" paneline geçer. `.zip` bırakılınca kurulmayacağı söylenir.
7. Açık ve koyu temada okunur (elle kontrol).
8. `KopruCore` birim testleri geçer.

## 2. Kararlar

| Konu | Karar |
|---|---|
| Yer | Ana pencerenin detay sütununda bir sayfa. Kenar çubuğu seçimi `enum SidebarItem { case install, bottle(Bottle.ID) }`. `InstallSheet` kalkar; `InstallProgressView` yalnızca kenar çubuğundaki "Boş Bottle…" için (o akış bu sayfanın dışında) sheet olarak kalır. |
| Pencere | İlk açılış 1280 × 800 pt (taslaktaki boyut; kartlar 3 sütun). En küçük boyut 1040 × 560 pt (kenar çubuğu + iki sütunlu ızgara + 340 pt panel sığsın; v0.1'de 780 × 480). |
| Sağ panel | SwiftUI `.inspector` (macOS 14+), yalnızca bu sayfada ve her zaman açık; genişlik 300–420 pt, varsayılan 340. Bottle sayfalarında yok. |
| Başlık ve arama | İçerikte büyük başlık "Program kur" ve aynı satırın sağında 280 pt arama alanı (`TextField` + `@FocusState`). Pencere başlığı `navigationTitle("Program kur")` ile Mission Control'de görünür, araç çubuğunda gizlenir (`.toolbar(removing: .title)`). `.searchable` kullanılmaz: macOS 14'te ⌘F ile odaklama (`searchFocused`) yok. |
| ⌘F | Düzen menüsüne "Programlarda Ara" komutu (⌘F); seçim Program kur'a geçer ve arama odaklanır. |
| Uyumluluk etiketleri | `RecipeRating`'e `perfect` eklenir. Etiketler: `perfect` **Sorunsuz** (yeşil), `works` **Çalışıyor** (camgöbeği), `partial` **Kısmen çalışıyor** (turuncu), `broken` **Şimdilik çalışmıyor** (kırmızı). Tarifi olmayan "Yakında" girdileri için ayrıca **Test ediliyor** (gri). |
| Kategoriler | `RecipeCategory`: `game` Oyun, `business` İş ve muhasebe, `engineering` Mühendislik, `office` Ofis. Hiç programı olmayan kategori kapsülü gizlenir. |
| Simgeler | `RecipeFiles/<id>/icon.png` (programın kendi simgesinin en büyük boyutu, genelde 256 px; `Tools/tarif-simgesi` ile exe'den çıkarılır) varsa o; yoksa kategoriye göre SF Symbol (gamecontroller, building.columns, ruler, doc.text) nötr kutuda. Taslaktaki harfli renkli kutular yer tutucuydu. |
| "Yakında" verisi | Tarif olmadan, ayrı bir dosyada: `Resources/Catalog/upcoming.json`. Kaynağı Sheets'teki 20 programlık test listesi (tarifi olanlar hariç). |
| "Haber ver" | **Bu sürüme girmez.** Sunucu (Supabase) ister; Faz 2'de. "Yakında" panelinde onun yerine "Kurulum dosyan varsa dene" yolu var. |
| Eşzamanlı kurulum | Bir anda bir kurulum (v0.1'deki gibi). Sürerken diğer kartların panelinde **Kur** yerine "Önce süren kurulum bitsin." yazar. |
| Kurulum bitince | Sayfa değişmez (kullanıcı başka programlara bakıyor olabilir). Yeni bottle kenar çubuğunda belirir, kart "Kurulu" olur, panel **Aç** ve **Bottle'a git** gösterir. |
| Aynı tarifi ikinci kez kurma | Bu sürümde yok; kurulu tarifin panelinde **Kur** görünmez. |
| Tarif dosyası bozuksa | Katalog dosya dosya okunur; bozuk dosya atlanır ve günlüğe yazılır (v0.1'de tek bozuk tarif bütün kataloğu boşaltıyordu). |

## 3. Veri

### 3.1 Tarife eklenen alanlar

Hepsi isteğe bağlı; eski tarifler çözülmeye devam eder (`schema` 1 kalır). Eksik alanın bölümü panelde gösterilmez.

```json
{
  "schema": 1,
  "id": "steam",
  "name": "Steam",
  "publisher": "Valve",
  "summary": "Oyun mağazası ve başlatıcısı",
  "category": "game",
  "rating": "works",
  "verdict": "Mağaza, kütüphane, indirme ve oyunlar açılıyor. Oyun içi Steam katmanı kapalı.",
  "testedOn": { "date": "2026-11-20", "hardware": "Apple M3", "macOS": "26.6" },
  "downloadNote": "2 MB, ilk açılışta yaklaşık 400 MB güncelleme",
  "highlights": [
    { "title": "Tarayıcı yardımcısı düzeltmesi", "detail": "Mağaza penceresi siyah açılmaz" },
    { "title": "Sanal masaüstü", "detail": "Pencere sol üste yapışmaz, kesilmez" },
    { "title": "Steam katmanı kapalı", "detail": "Oyun açılırken çökmeyi önler" },
    { "title": "MSync açık", "detail": "Oyunlarda daha akıcı kare hızı" }
  ]
}
```

Örnekte gösterilmeyen v0.1 alanları (`bottle`, `installer`, `afterInstall`, `beforeLaunch`, `whileRunning`, `launch`, `detect`, `hideShortcuts`) aynen kalır.

- `summary` artık yayıncı adını içermez (yayıncı ayrı alanda; kartta özet, panelde "Yayıncı · özet").
- `highlights` elle yazılır; tarif eylemlerinden türetilmez (eylemler teknik, kullanıcı ne kazandığını görmeli). Her madde tarifte gerçekten yapılan bir şeye karşılık gelmeli.
- `testedOn` panelde "Son test: 20 Kas 2026 · Apple M3 · macOS 26.6" olur.
- `category` serbest metin olmaktan çıkar, `RecipeCategory` olur; bilinmeyen değer o tarifin atlanmasına yol açar (2. bölüm, son satır).

### 3.2 Yakında listesi

`Resources/Catalog/upcoming.json` (yeni kaynak klasörü; `project.yml`'e eklenir):

```json
[
  { "id": "epic", "name": "Epic Games Launcher", "publisher": "Epic Games",
    "summary": "Oyun mağazası ve başlatıcısı", "category": "game", "status": "broken",
    "note": "Başlatıcı ilk kurulumda takılıyor. Yeni motor sürümüyle yeniden deneniyor." },
  { "id": "gog-galaxy", "name": "GOG Galaxy", "publisher": "GOG",
    "summary": "Oyun mağazası ve başlatıcısı", "category": "game", "status": "testing" }
]
```

- `status`: `testing` (Test ediliyor) ya da `broken` (Şimdilik çalışmıyor). `publisher` ve `note` isteğe bağlı; yayıncısından emin olunmayan girdide `publisher` yazılmaz.
- Bir `id` hem tarif hem "Yakında" olarak varsa tarif kazanır, "Yakında" girdisi gösterilmez (tarif eklenince listeden silmeyi unutmak zarar vermez).
- Dosya yoksa ya da bozuksa "Yakında" bölümü gizlenir, günlüğe yazılır.
- İçerik Sheets'teki test listesinden alınır (Faz 0 Test Listesi, "Testler" sayfası). Kurulabilir programlar girer: Epic Games Launcher, GOG Galaxy, Logo Go 3 / Tiger, ETA:SQL, Mikro, Excel 2016, Matriks, NetCAD, ideCAD Statik. Steam'den kurulan oyunlar (Bannerlord, Age of Empires II, Skyrim, GTA V, Counter-Strike 2, Thief Simulator 2 vb.) girmez, onları Steam kurar; belirli bir ürün adı olmayan "E-imza programı" da girmez. Taslaktaki Battle.net ve "Mikro Jump" listede yoktu, çıkarıldı.

### 3.3 Yeni tarifler

| Tarif | Kaynak | Not |
|---|---|---|
| Notepad++ | Resmî GitHub sürümü, sessiz kurulum `/S`, `sha256` dolu | Faz 0'da WineHQ 11.0 bottle'ında çalıştı; Köprü motorunda (CX 26.3) yeniden test edilir. |
| WinRAR (Türkçe) | Resmî Türkçe x64 kurulum dosyası, `/S`, `sha256` dolu | Faz 0'da Rar.exe ve `.rar` ilişkilendirmesi çalıştı; Köprü'de yeniden test edilir. |

Etiket ve `verdict`, Köprü'deki testten sonra yazılır; test geçmeden tarif "Kurulmaya hazır"a girmez.

### 3.4 KopruCore'a eklenenler

- `Recipe`: `publisher`, `verdict`, `testedOn: RecipeTestInfo`, `downloadNote`, `highlights: [RecipeHighlight]` (hepsi `Optional`), `category: RecipeCategory`.
- `RecipeRating.perfect`; `broken` etiketi "Şimdilik çalışmıyor".
- `RecipeCategory` (`label`, `symbolName`).
- `UpcomingProgram` ve `UpcomingStatus`.
- `CatalogEntry` (`recipe` / `upcoming`) ve `CatalogSections` (`ready`, `upcoming`).
- `RecipeCatalog`: dosya dosya okuma (bozuk dosyayı atla, `problems`'a yaz), `upcoming` listesi, `sections(matching:category:)` (ad, özet, yayıncı; büyük/küçük harf, aksan ve Türkçe `ı`/`i` duyarsız; `nil` kategori hepsi), `count(in:)`, `categories`, `entry(id:)`, `iconURL(for:)`. v0.1'deki `search(_:)` kalkar.
- `[Bottle].withRecipe(_ id: String) -> [Bottle]` (tarifin kurulu olduğu bottle'lar, `recipeId` eşleşmesi).

## 4. Ekran

### 4.1 Kenar çubuğu

- En üstte kemer simgesi ve "Köprü" adı; altında **Program kur** satırı (`plus.circle`, vurgu renginde), sonra "Bottle'lar" bölümü (v0.1'deki gibi; çalışan bottle'da yeşil nokta).
- En altta "+ Boş bottle" (tıklayınca boş bottle; basılı tutunca "Bottle İçe Aktar…"). İkisi Dosya menüsünde de var: "Boş Bottle…" (⌘N) ve "Bottle İçe Aktar…" (Dosya menüsündeki "Yeni Pencere" kalktı).
- Bottle satırı, bottle bir tarife bağlıysa ve tarifin simgesi varsa o simgeyi, yoksa `shippingbox` gösterir.
- Açılışta seçim: hiç bottle yoksa Program kur, varsa ilk bottle (v0.1 davranışı).

### 4.2 Sayfa (orta sütun)

Yukarıdan aşağı:

1. **Satır 1:** "Program kur" (büyük başlık) · sağda arama alanı ("Program ara", ⌘F ipucu).
2. **Satır 2:** kategori kapsülleri (Tümü ve kategoriler, yanlarında aramadan bağımsız toplam sayı) · sağda "Listede yok mu? **Dosya seç…**" (dosya seçici: `.exe`, `.msi`).
3. **Kurulmaya hazır** — "Köprü ekibi test etti": `broken` olmayan tarifler, ada göre sıralı.
4. **Yakında** — "Test ediliyor": `broken` tarifler ve `upcoming.json` girdileri.
5. Süzgeç boşsa: "“sorgu” için hazır tarif yok" + "Kurulum dosyan varsa pencereye sürükle; Köprü onu yeni bir bottle'a kurar." + **Dosya seç…**

Kart ızgarası: `LazyVGrid`, uyarlanır sütun (en az 200 pt). Kart: 42 pt simge, ad (tek satır), özet (en çok iki satır), rozet. Seçili kart vurgu renginde çerçeve. Tek tık seçer, çift tık kurulu kartta açar.

### 4.3 Kart ve panel durumları

| Durum | Kart | Sağ panel |
|---|---|---|
| Hazır, kurulu değil | Uyumluluk rozeti | Başlık · rozet + `verdict` · son test · "Köprü senin yerine ayarlar" (`highlights`) · "İndirilecek" (`downloadNote`) · altta bottle adı alanı, "internet gerekli", **Kur** |
| Hazır, kurulu | "✓ Kurulu" + **Aç** | Aynı ayrıntı · altta "“Steam” bottle'ında kurulu", **Bottle'a git**, **Aç** |
| Kuruluyor | "Kuruluyor" + yüzde (indirmede) | Adım listesi (Bottle hazırlanıyor, İndiriliyor + çubuk, Kuruluyor, Ayarlanıyor) · "Bu sırada başka programlara göz atabilirsin." |
| Kurulum başarısız | "Kurulamadı" (kırmızı) | Kalınan adım ✕ · hata metni (seçilebilir) · **Günlüğü göster** · yeni bottle açıldıysa **Yarım bottle'ı sil** / **Tut ve kapat** |
| Kuruldu (bu oturumda) | "✓ Kurulu" + **Aç** | Adımlar ✓ · **Bottle'a git**, **Aç** |
| Yakında, test ediliyor | Gri rozet | Açıklama: "Bu program için kurulum tarifi hazırlanıyor." · "Kurulum dosyan varsa genel ayarlarla deneyebilirsin." · **Dosya seç…** |
| Yakında / tarif, şimdilik çalışmıyor | Kırmızı rozet | `note`/`verdict` · **Yine de dene…** (dosya seçici → listede olmayan program) |
| Listede olmayan dosya | (kart yok, hiçbir kart seçili değil) | Dosya adı ve boyutu · "Bu program için Köprü'de hazır ayar yok; genel Windows 10 ayarlarıyla kurulur." · "Ne olacak" (kurulum penceresi açılır; kapanınca programlar listeye eklenir) · **Nereye kurulsun** (Yeni bottle / mevcut bottle'lar) · yeni ise bottle adı · **Vazgeç**, **Kur** |

- Bottle adı çakışırsa alanın altında "Bu adla bir bottle var." ve **Kur** basılınca kurulum başlamaz (v0.1 kuralı).
- Başka bir kurulum sürerken **Kur** yerine "Önce süren kurulum bitsin." yazar.
- **Aç**, tarifin başlatıcısını o bottle'da açar; sayfa değişmez. **Bottle'a git** o bottle'ı seçer.
- **Return:** arama alanındayken yalnızca ilk sonucu seçer (yanlışlıkla kurulum başlamasın); arama dışındayken panelin ana düğmesine (**Kur** / **Aç**) basar.

### 4.4 Sürükle-bırak

- Ana pencerenin detay sütunu (`dropDestination(for: URL.self, isTargeted:)`) her sayfada dosya kabul eder.
- Sürüklerken detay sütununu kaplayan katman: kesikli vurgu çerçevesi, buzlu arka plan, simge, "Bırak, kuralım", ".exe ve .msi kurulum dosyaları".
- Bırakılan ilk `.exe`/`.msi` → seçim Program kur'a geçer, panel "Listede olmayan dosya" durumuna geçer. **Nereye kurulsun** varsayılanı: bırakmadan önce bir bottle sayfasındaysa o bottle, değilse Yeni bottle.
- Hiç `.exe`/`.msi` yoksa: "Yalnızca .exe ve .msi kurulum dosyaları kurulabilir." uyarısı.

### 4.5 Araç çubuğu

- Program kur sayfasında: bottle düğmeleri (C: Sürücüsü, Program Çalıştır…, Durdur, Ayarlar) görünmez.
- Bottle sayfalarında: v0.1'deki düğmeler; **Kur** Program kur sayfasına geçer.

## 5. Akış değişiklikleri (v0.1 4.1 ve 4.2'ye göre)

- **Tarifle kurulum:** 1. adım artık "kart seç → panelde bottle adını onayla → **Kur**". Adımlar ve hata davranışı aynı; gösterim sheet yerine panel. `finishInstall` bottle'ı seçmez; yalnızca listeyi yeniler.
- **Listede olmayan program:** dosya üç yoldan gelir (Dosya seç…, sürükle-bırak, "Yine de dene…"). Gerisi v0.1 4.2.
- **İlerleme durumu:** `InstallProgress`'e kaynağı eklenir (`recipe(id)` ya da `unlisted(URL)`), böylece kart ve panel hangi kurulumun kendilerine ait olduğunu bilir.

## 6. Hata durumları

v0.1 tablosu geçerli; ekler:

| Durum | Kullanıcının gördüğü |
|---|---|
| Kurulum dosyası olmayan bir şey bırakıldı | "Yalnızca .exe ve .msi kurulum dosyaları kurulabilir." |
| Bir tarif dosyası bozuk | O tarif listede yok; diğerleri görünür. Günlükte dosya adı ve çözümleme hatası. |
| `upcoming.json` yok ya da bozuk | "Yakında" bölümü görünmez; günlükte hata. |
| Tarif simgesi yok | Kategori simgesi. |

## 7. Testler

- **Birim (`swift test`, KopruCore):**
  - Yeni alanlı tarif ve v0.1 biçimindeki tarif (yeni alanlar yok) çözülür.
  - `rating: "perfect"` çözülür; bilinmeyen `category` o tarifi atlatır, diğerleri yüklenir.
  - Bozuk bir `.json` kataloğu boşaltmaz.
  - `upcoming.json` çözülür; tarifle aynı `id`'ye sahip girdi elenir; dosya yoksa liste boş.
  - Arama: ad, özet, yayıncı; "NOTEPAD" ~ "Notepad++", "valve" ~ "Valve", "baslaticisi" ~ "başlatıcısı" (ş ve ı), "arsivleme" ~ "Arşivleme"; kategori süzgeci aramayla birlikte.
  - `withRecipe(_:)`: `recipeId` eşleşen bottle'lar.
  - Depodaki her tarif çözülür; yayıncı, açıklama ve test bilgisi dolu; `broken` olmayanların `icon.png`'si var. Depodaki `upcoming.json` çözülür ve tariflerle aynı `id`'yi taşımaz.
- **Elle (Umut; bu oturumların ekran kaydı izni yok):** başarı ölçütleri 1–7. Steam'in başarılı kurulumu ev ağında, başarısız kurulum (ölçüt 5) ofis ağında.

## 8. Bu tasarıma girmeyenler

"Haber ver" ve bekleyen kişi sayısı (sunucu ister, Faz 2); çevrimiçi tarif güncellemesi; kullanıcı puanları; aynı tarifi ikinci bir bottle'a kurma; aynı anda birden çok kurulum; klavye okuyla kartlar arasında gezinme; "Ana sayfa" / öneriler; kenar çubuğunda bottle simgesi dışındaki yeniden tasarım.

## 9. Riskler ve açık noktalar

- **"Yakında" bir söz gibi okunabilir.** "Test ediliyor" tarih vermiyor; çalışmayacağı anlaşılan program listeden çıkarılır. Logo / ETA / Mikro gibi muhasebe programları SQL Server, e-imza ve donanım kilidi yüzünden hiç çalışmayabilir; liste kapalı betada küçük tutulur.
- **Program simgeleri** üreticinin markası. CrossOver da kullanıyor; kapalı beta için sorun değil, halka açık sürümden önce gözden geçirilir.
- **`.inspector` + `NavigationSplitView`** macOS 14'te sütun genişliklerini beklenmedik bölebilir; plan aşamasında küçük bir denemeyle doğrulanır, sorun çıkarsa panel `HSplitView` ile yapılır.
- **Ofis ağında indirme** Steam için zaten başarısız; Notepad++ ve WinRAR indirmelerinin ofiste geçip geçmediği bilinmiyor.
