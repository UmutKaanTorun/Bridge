# Köprü — Program kur: yalnızca oyun platformları, tek tıkla kurulum

- **Tarih:** 2026-11-21
- **Durum:** Uygulandı (2026-11-21, main; "Program kur: yalnızca oyun platformları…" ve önceki iki commit); kurulum akışı arayüzde elle denenmedi
- **Önceki tasarımın yerine geçen kısımlar:** [`2026-11-20-kur-ekrani-design.md`](2026-11-20-kur-ekrani-design.md) §2 (sağ panel, kategoriler, "Yakında"), §4.2–4.3 (sayfa, kart ve panel durumları). Arama, ⌘F, sürükle-bırak ve listede olmayan dosya akışı aynı kaldı; dosya akışı panelden pencereye (sheet) taşındı.

## İstek

Umut: "CrossOver'daki gibi sadece platformlar olsun, tıkladığımızda indirip kursun." Seçtikleri: altı platformun hepsine tarif yazılsın ve burada denensin, kart dürüst bir etiket alsın; sağ panel kalksın.

## Kararlar

| Konu | Karar |
|---|---|
| İçerik | Yalnızca oyun kategorisindeki tarifler (`RecipeCatalog.platforms(matching:)`). İş/mühendislik/ofis programları ve "Yakında" listesi bu sayfada görünmez; `upcoming.json` veri olarak duruyor. |
| Düzen | CrossOver gibi iki sütunlu liste (min. sütun 340 pt), satır altı çizgi, 52 pt simge. Sağ panel ve kategori kapsülleri yok. |
| Sıralama | Önce iyi çalışan (`RecipeRating.rank`), sonra ada göre. |
| Tıklama | Kurulu değilse indirip kurar (bottle adı sorulmaz; doluysa "Steam 2"); kuruluysa açar. Kurulum sürerken öteki satırlar soluk ve tıklanmaz. |
| Çalışmayan platform | Tıklayınca onay: "X şu an Köprü'de çalışmıyor", gerekçe cümlesi, **Yine de kur** / **Vazgeç**. |
| Kurulum sırasında | Satırda adım + yüzde + çubuk, sağda **Durdur** (indirmeyi ya da takılan kurulum programını keser, yarım bottle silinir). |
| Kurulum bitince | İlerleme kaybolur, satır "Kurulu" + **Aç**. Kurulum programı hatasız bitse de `detect` dosyaları yoksa hata sayılır ("Kurulum bitti ama X bottle'da bulunamadı."). |
| Hata | Satırda kırmızı "Kurulamadı: …", **Günlük**, **Tekrar dene** (yarım bottle'ı silip baştan), ✕ (yarım bottle kenar çubuğunda kalır). Sağ tık menüsünde "Yarım bottle'ı sil". |
| Listede olmayan dosya | "Kurulum dosyası seç…" ya da sürükle-bırak → 460 pt'lik pencere (eski panel içeriği). Kurulum sürerken **Gizle**; gizliyken sayfanın üstünde dönüş şeridi. |
| Yeni etiket | `RecipeRating.opens` → **Açılıyor** (gri): kurulup giriş ekranına kadar açıldığı görüldü, giriş ve oyunlar denenmedi. |

## Deneme sonuçları (2026-11-21, Apple M3, macOS 26.6, CX 26.3.0 + DXMT 0.80, ofis ağı)

`PlatformTrialTests` (gerçek motor, gerçek ağ; `KOPRU_TARIF_DENE=<id,…>`) Köprü'nün kendi kurulum koduyla kurup açtı. Bottle'lar `~/WineBottles/kopru-platform`'da duruyor.

| Platform | Kurulum | Açılış | Etiket |
|---|---|---|---|
| Steam | ✓ (önceki tarif) | ✓ giriş, mağaza, oyun | Çalışıyor |
| Epic Games Launcher | ✓ MSI `/qn`, 63 sn | ✓ Türkçe giriş ekranı | Açılıyor |
| GOG Galaxy | ✓ Inno `/VERYSILENT`, 95 sn | ✗ giriş formu yüklenip 1 sn sonra çöküyor; Qt/Chromium GPU'suz bayraklarla da | Şimdilik çalışmıyor |
| EA App | ✗ WiX Burn, "güncelleme denetimi"nde sonsuza dek bekliyor (arayüzlü modda da; ağ isteği 200 dönüyor) | — | Şimdilik çalışmıyor |
| Ubisoft Connect | ✓ NSIS `/S`, 51 sn | ✗ beyaz pencere: `cross-process swapchain not supported` (Steam'deki sorun); UplayWebCore'da d3d11/dxgi kapatmak düzeltmedi | Şimdilik çalışmıyor |
| Battle.net | ✓ 92 sn (kurucu Battle.net'i kendisi açar) | ✗ giriş penceresi boş, libcef `int3` çökmesi | Şimdilik çalışmıyor |
| Rockstar Games Launcher | ✓ WiX Burn `/quiet`, 118 sn | ✗ "failed to initialize 00000003"; DXMT `SwapDeviceContextState` desteklemiyor | Şimdilik çalışmıyor |

Kurulum yolları: Epic ve GOG `Program Files`'a (x86 değil) kurulur. Kurulum dosyaları ofis ağında sorunsuz indi (FortiGate yalnızca Steam alan adlarını denetliyor).

## Açık noktalar

- Chromium/CEF tabanlı başlatıcılar (Ubisoft, Battle.net, muhtemelen GOG ve Rockstar) Steam'deki çizim sorununa takılıyor. Kalıcı çözüm motor tarafında (macdrv'de süreçler arası çizim) ya da her biri için Steam'deki gibi bir aracı.
- Battle.net kurucusu kurulumdan sonra Battle.net'i açıyor; şu an çöküp Wine hata pencereleri bırakıyor.
- Tek tıkla kurulum, Durdur ve Tekrar dene arayüzde elle denenmedi (tık gönderilemiyor). Durumlar Debug'da `KOPRU_SAHTE_KURULUM=indiriliyor:epic|hata:<id>` ile görüntülendi; `KOPRU_SAYFA=kur` Debug'ı Program kur'da açar.
