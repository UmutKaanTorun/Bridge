# Köprü — Program kur: yalnızca oyun platformları, tek tıkla kurulum

- **Tarih:** 2026-11-21
- **Durum:** Uygulandı (2026-11-21, main; "Program kur: yalnızca oyun platformları…" ve önceki iki commit); kurulum akışı arayüzde elle denenmedi. İkinci tur (aynı gün): Ubisoft, Battle.net ve GOG düzeldi ("Kök nedenler ve düzeltmeler"). Üçüncü tur (aynı gün, Umut onayıyla motor yaması): Rockstar düzeldi: program başına wined3d, Social Club aracısı, sessiz kurulum `/s /f` ([grafik spec'i](2026-11-21-rockstar-grafik-motoru-design.md)).
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
| GOG Galaxy | ✓ Inno `/VERYSILENT`, 95 sn (taze denemede 58 sn) | ✓ giriş ekranı (ikinci tur: `config.json`'da `--disable-gpu`; ilk turda 1 sn sonra çöküyordu) | Açılıyor |
| EA App | ✓ WiX Burn `/quiet`, 54 sn (üçüncü tur: motora Gecko + Mono; ilk iki turda "güncelleme denetimi"nde sonsuza dek bekliyordu, aşağıda) | ✓ giriş ekranı (`EADesktop.exe --in-process-gpu`; `EALauncher` bayrağı geçirmiyor, pencere boş kalıyordu) | Açılıyor |
| Ubisoft Connect | ✓ NSIS `/S`, 51 sn | ✓ giriş ekranı, ilk açılıştaki kendini güncellemeden sonra da (ikinci tur: `--in-process-gpu`; ilk turda beyaz pencere) | Açılıyor |
| Battle.net | ✓ 92 sn (taze denemede 58 sn; kurucu Battle.net'i kendisi açar, tarif kapatır) | ✓ giriş ekranı (ikinci tur: `--in-process-gpu` + V8 bayrağı; ilk turda boş pencere ve `int3`) | Açılıyor |
| Rockstar Games Launcher | ✓ Rockstar'ın kendi sessiz argümanı `/s /f`, 11 sn (üçüncü tur; ilk turdaki `/quiet` tanınmıyordu, dil penceresi elle onaylanmıştı) | ✓ giriş ekranı, ilk açılışta Social Club'ı kendisi kurduktan sonra da (üçüncü tur: Launcher program başına wined3d + OpenGL, Social Club'a `--in-process-gpu` aracısı; ilk turda "failed to initialize 00000003", aşağıda). Hesapla giriş, kitaplık ve mağaza da çalışıyor (saat dilimi yamasından sonra) | Açılıyor |

Kurulum yolları: Epic ve GOG `Program Files`'a (x86 değil) kurulur. Kurulum dosyaları ofis ağında sorunsuz indi (FortiGate yalnızca Steam alan adlarını denetliyor).

## Kök nedenler ve düzeltmeler (ikinci tur, 2026-11-21)

Her biri gerçek motorla izlendi (`WINEDEBUG=+process,+seh,+loaddll`, platformların kendi günlükleri) ve düzeltmeler `~/WineBottles/kopru-platform-taze`'de Köprü'nün kurulum koduyla **sıfırdan kurulup** açılarak doğrulandı (`PlatformTrialTests`, ekran görüntüleri ayrı alındı). Steam aracısını genelleştirmek gerekmedi: üç düzeltme de tarifte bayrak ya da ayar.

Ortak nokta: hata macdrv'den değil **DXMT'den** geliyor. `cross-process swapchain not supported yet` DXMT'nin `d3d11.dll`'inin iletisi: Chromium'un ayrı GPU süreci, tarayıcı sürecinin penceresine swapchain açmak istiyor, DXMT bunu reddediyor. GPU iş parçacığı pencerenin sahibi süreçte çalışınca (`--in-process-gpu`) DXMT normal çiziyor (D3D 11_1); Steam'deki gibi `--single-process` ya da GPU'yu tümden kapatmak gerekmiyor.

### Ubisoft Connect — düzeldi (Açılıyor)

- Tarayıcı süreci `UbisoftConnect.exe`'nin kendisi (CEF 135, süreç içi); `UplayWebCore.exe` yalnız alt süreç (gpu-process, renderer, utility). İlk turdaki AppDefaults `UplayWebCore.exe` denemesi bu yüzden yanlış süreci hedefliyordu.
- GPU süreci swapchain açamayıp 60 sn'de 14 kez çöküp yeniden başlıyordu.
- **Düzeltme:** `launch.arguments: ["--in-process-gpu"]` (CEF tarayıcı süreci kendi komut satırını okur). Taze kurulumda ilk açılış 168 → 175 kendini güncelleyip yeniden başlıyor; bayrak yeniden başlatmada da korunuyor, giriş ekranı geliyor.

### Battle.net — düzeldi (Açılıyor)

İki ayrı neden (CEF 108, 32 bit; tarayıcı süreci `Battle.net.exe`):

1. GPU süreci aynı swapchain hatası → `--in-process-gpu`. Yalnız bu yetmiyor: web alanı siyah, renderer çöküyor.
2. Renderer `int3`'ü: libcef+0x16D00E1 `VirtualProtect(…, PAGE_READONLY, &old)` sonrasında `CHECK(old == PAGE_READWRITE)`. Korunan sayfa libcef'in `.data` bölümünde ve çağıran önce "donduruldu" bayrağını yazıyor: V8'in başlatmadan sonra bayraklarını salt okunur yapması (`freeze_flags_after_init`). Wine'ın `VirtualProtect`'i burada eski koruma olarak `PAGE_READWRITE` dışında bir değer döndürüyor (büyük olasılıkla kopyala-yaz image sayfası için `PAGE_WRITECOPY`; değer ayrıca okunmadı). Ubisoft'taki CEF 135 bu denetime takılmıyor. → `--js-flags=--no-freeze-flags-after-init` (CEF bunu renderer'a geçiriyor).

- `--no-sandbox` etkisiz; yalnız V8 bayrağıyla swapchain hatası sürüyor. İki bayrak birlikte gerekli.
- Kurucu bitince Battle.net'i bayraksız açıyor ve bu örnek çöküyor. Battle.net tek örnekli olduğu için sonraki **Aç** yeni süreç yerine o bozuk örneği öne getirir. Kurucuda "açma" seçeneği yok → yeni eylem `stopPrograms` (`wineserver -k`) `afterInstall`'da.
- `launch.windowsPath` artık doğrudan `Battle.net.exe`: `Battle.net Launcher.exe` 5 sn'de çıkıyor ve Köprü programı bitmiş sanıyordu (ilk turdaki "çıkış kodu 0, 5 sn"). Bayraklar Launcher'dan da geçiyor.

### GOG Galaxy — düzeldi (Açılıyor)

- Qt 6.7 WebEngine (Chromium 118); GPU iş parçacığı zaten süreç içinde. Çökme `GalaxyClient.exe`'nin kendisinde: `Qt6WebEngineCore.dll`+0x292ada'da null+8 okuma, hemen önce "Compositor returned null texture".
- Neden: Qt'nin D3D11 birleştiricisi Chromium'un çizdiği paylaşımlı dokuyu `IDXGIKeyedMutex` ile açıyor; DXMT bu arabirimi tanımıyor (`Unknown interface query 9d8e1289-…`), doku null geliyor ve Qt onu denetlemeden kullanıyor.
- İlk turdaki denemeler neden tutmadı: GalaxyClient `QTWEBENGINE_CHROMIUM_FLAGS`'ı `C:\ProgramData\GOG.com\Galaxy\config.json`'daki `chromiumClientAppArguments`'tan kendisi kuruyor (ortam değişkeni eziliyor); komut satırındaki `--disable-gpu` da etkisiz. Ayar metin değil nesne olmalı (Galaxy günlüğü: "does not contain map object").
- **Düzeltme:** `beforeLaunch`'ta yeni `jsonValues` eylemi config.json'a `"chromiumClientAppArguments": {"--disable-gpu": ""}` yazar (öteki anahtarlar korunur; Galaxy anahtarı yerinde bırakıyor). Chromium yazılımla birleştiriyor; taze kurulumda giriş ekranı 2 dk açık kaldı, çökme raporu yok.

### Rockstar Games Launcher — düzeldi (Açılıyor; motor yaması + Social Club aracısı)

- Zincir: `Launcher.exe` → `LauncherPatcher.exe` → `Launcher.exe` (1.0.110). Asıl Launcher "Initializing engine / group 1"de **3** koduyla çıkıyor (`abort()`'un çıkış kodu; `Documents/Rockstar Games/Launcher/prelauncher.log`: "Launcher exited with code: 3"). Ön başlatıcı "failed to initialize 00000003" gösteriyor; kendini güncelleme denemesinden sonra bazen 00000010.
- Launcher arayüzünü Wine'ın yerleşik `d2d1.dll`'i çiziyor (DC render target'lar, DXMT'nin D3D11 FL10_0 aygıtı). d2d1 ilk `Clear`'da durumu kaydetmek için `ID3D11DeviceContext1::SwapDeviceContextState` çağırıyor; DXMT 0.80'de uygulanmamış, hata yazıp süreci sonlandırıyor (`+d2d` izi tam o satırda bitiyor).
- Tarif düzeyinde denenen: `AppDefaults\Launcher.exe\DllOverrides` + motorun `orijinal-grafik` klasöründeki Wine d3d11/dxgi/d3d10core. Uygulama klasöründe: d2d1 → d3d10_1'in içe aktarımları yalnız system32'de aranıyor. system32'de: "native" yükleme sırası Wine yerleşiği olarak işaretli dosyaları kabul etmiyor; yerleşikler yalnız motor klasöründen yükleniyor. Yani tarifle tek bir program için wined3d'ye geçilemiyor. (Deneme bottle'ı eski hâline getirildi.)
- İkinci turdaki değerlendirme: çözüm motor tarafında (DXMT'ye `SwapDeviceContextState` eklemek, DXMT'nin bunu içeren bir sürümüne geçmek ya da motor paketine özgün d3d11'i koyup grafik arka ucunu seçmek); Social Club (CEF) ayrıca denenmeli.
- Üç yol araştırılıp denendi: [`2026-11-21-rockstar-grafik-motoru-design.md`](2026-11-21-rockstar-grafik-motoru-design.md). Yamalı DXMT'de Launcher "Initializing engine"i geçip GDI yüzeyi eksikliğinde çöküyor; bütün bottle wined3d + OpenGL'de Launcher açılıp Social Club'ı kuruyordu (o denemede Sign In beyazdı). Seçilen yol: program başına wined3d (küçük ntdll yaması).
- **Uygulandı (Umut onayıyla):** `Tools/motor-yamalari/ntdll-program-basina-wined3d.patch` + `BottleSettings.wined3dPrograms` (`KOPRU_WINED3D_EXE`); tarif `["Launcher.exe"]` ve `AppDefaults\Launcher.exe\Direct3D\renderer=gl` yazıyor. Launcher artık açılıyor ve Social Club'ı kuruyor. Ayrıntı: grafik spec'inin 4. bölümü.
- **Social Club giriş penceresi:** beyaz kalıyordu; CEF'in ayrı GPU süreci tarayıcı sürecinin penceresine swapchain açamıyor (DXMT `cross-process swapchain not supported`; Steam/Ubisoft/Battle.net'teki sorun). Launcher SocialClubHelper'a bayrak geçirmiyor → yeni genel tarif eylemi `helperProxy`: `SocialClubHelper.exe`'nin yerine `--in-process-gpu` ekleyen aracı (`Tools/cef-araci`), `beforeLaunch` + `whileRunning`. Giriş ekranı ilk açılışta da çiziliyor; not **opens**. Ayrıntı: grafik spec'inin 5. bölümü.
- **Kurulumdaki dil penceresi:** Rockstar'ın kurulum programı `/quiet`'i tanımıyor ("Normal install mode", dil seçimi bekliyor; ilk denemedeki kurulum elle onaylanmıştı). Rockstar'ın kendi sessiz argümanı `/s /f` (1.0.105.2705 notu) → penceresiz, ~10 sn, Launcher'ı kendiliğinden açmıyor.
- **Hesapla giriş:** 1.000.7 ("unable to handle your request") ile reddediliyordu; aynı hesap tarayıcıda giriyordu. Neden Wine'ın İstanbul'u "Arab Standard Time" (Riyad) olarak göstermesi: aynı kurala (+03, yaz saati yok) uyan kayıtlardan alfabede ilkini seçiyor. Motor yaması `Tools/motor-yamalari/ntdll-saat-dilimi.patch` ana makinenin saat dilimine karşılık gelen kaydı seçtiriyor (macOS ICU). Umut'un bottle'ında önce/sonra denendi: giriş oldu, kitaplık (GTA V Enhanced) ve mağaza açıldı. Bütün programlar için saat dilimini düzeltir. Ayrıntı: grafik spec'inin 6. bölümü.

### EA App — düzeldi (Açılıyor; motora Gecko + Mono, üçüncü tur)

Geliştirme motoruyla (`~/WineEngines/WineCX26.3.0-DXMT0.80`), `kopru-platform`'daki EA bottle'ının geçici kopyasında, `EAappInstaller.exe /quiet EAX_LAUNCH_CLIENT=0` elle çalıştırılarak izlendi (`WINEDEBUG=+loaddll,+seh,+process,+thread`, kurucunun `%TEMP%\EA_app_*.log` Burn günlüğü). Art arda iki ayrı engel var, ikisi de aynı eksiklikten:

1. **Görünmeyen Gecko penceresi (sonsuz bekleme).** EA'nın Burn arayüzü (EAXBA 13.832) güncelleme denetiminde `globalConfig.json`'u indiriyor (200; ilk turdaki gözlem bu), ardından bir iş parçacığı `mshtml.dll`'i yüklüyor. Wine'ın mshtml'i Gecko'yu bulamayınca `control.exe appwiz.cpl install_gecko`'yu açıp `WaitForSingleObject(…, INFINITE)` ile bekliyor (`dlls/mshtml/nsembed.c` `install_wine_gecko`); ekranda "Wine Gecko Installer" penceresi tıklanmayı bekliyor. Bu istemi kapatan bir kayıt defteri anahtarı yok (`dlls/appwiz.cpl/addons.c` `get_url` her zaman bir adres döndürüyor). Kanıt: Burn günlüğü 16:55:55'te `OnDetectUpdateBegin`'de duruyor, `control.exe` kapatıldığı anda (16:58:21) `OnDetectUpdateComplete` ile sürüyor. `WINEDLLOVERRIDES=mshtml=d` ile güncelleme denetimi 1 sn'de geçiyor: EA kurucusu Gecko'suz da ilerliyor.
2. **.NET özel eylemi (1603).** MSI'nin `JunoInitializeSession` eylemi yönetilen kod (WiX DTF, `juno-custom-actions`; `rundll32 … zzzzInvokeManagedCustomActionOutOfProc`). CLR yok: `mscoree: error reading registry key for installroot` (`HKLM\Software\Microsoft\.NETFramework\InstallRoot`'u Wine Mono'nun kurulumu yazar) → eylem 1603 → Burn `0x80070643`, geri alma, çıkış kodu 1. Kurulum mshtml kapalıyken 11 sn'de buraya varıyor.

Ortak neden: 26.3.0 motor paketinde `share/wine/gecko` ve `share/wine/mono` yok (eski `WineCX24.0.7-DXMT0.80` motorunda Gecko 2.47.4 ve Mono 9.0.0 vardı), Köprü de bottle'ları `wineboot`'a `mscoree=d;mshtml=d` vererek kuruyor. Bottle'larda ne Gecko ne Mono oluyor. 26.3.0'ın beklediği sürümler: Gecko 2.47.4 (x86 ve x86_64), Mono 10.4.1.

İki seçenek tartışıldı: motora Gecko + Mono ya da yalnız tarif (KopruCore'a kurulum öncesi adım, her EA kurulumunda 85 MB'lık Mono MSI'si, kurucuya `mshtml` kapalı; öteki programlardaki Gecko tuzağı sürerdi). **Umut motoru seçti; uygulandı:**

- **Motor:** geliştirme motoruna `share/wine/gecko/wine-gecko-2.47.4-x86{,_64}` (eski motordan; resmi dl.winehq.org arşivleriyle dosya dosya aynı) ve `share/wine/mono/wine-mono-10.4.1` (resmi `wine-mono-10.4.1-x86.tar.xz`). Mevcut dosyalara dokunulmadı, yalnız eklendi. Yeni `Scripts/motor-eklentileri.sh` aynısını SHA-256 denetimiyle yapıyor (bir sonraki motor derlemesi için); `Scripts/bundle-engine.sh` bunlar yoksa Release derlemesini durduruyor. Uygulama ~330 MB büyüyecek (Gecko 102 MB, Mono 231 MB; Release derlemesi yapılmadı).
- **`BottleFactory`:** `wineboot`'a `mscoree=d;mshtml=d` verilmiyor. Boş bottle'da denendi: pencere yok, mscoree Mono'yu motorda buluyor ve yalnız destek MSI'sini kuruyor (`.NETFramework\InstallRoot` yazılıyor), Gecko yerinde kullanılıyor. Bottle oluşturma 16 → 20 sn, bottle +7 MB. Eski bottle'larda Mono kayıtları yok (Gecko motordan hemen çalışır); .NET isteyen bir program eski bottle'da yine düşer.
- **Açılış:** kurulum bitince EA'nın giriş penceresi boştu: CEF 109 (`EADesktop.exe` tarayıcı süreci, `EACefSubProcess.exe --type=gpu-process`) → DXMT `cross-process swapchain not supported` (Steam/Ubisoft/Battle.net'teki sorun). `EALauncher.exe` → `EALaunchHelper.exe`'ye bayrak geçiyor, o da `EADesktop.exe`'yi sabit argümanlarla açıyor (`+process` izi). Tarif artık doğrudan `EADesktop.exe --in-process-gpu` açıyor; Battle.net'teki V8 bayrağı gerekmedi.
- **`detect`:** EA uygulamayı sürüm klasörüne (`EA Desktop\13.832.0.6345\EA Desktop`) kuruyor ve `EA Desktop\EA Desktop`'u oraya göreli dizin bağlantısıyla bağlıyor. Wine bağlantıyı Mac tarafında `EA Desktop?` adlı boş klasör + `user.WINEREPARSE` ek özniteliği (REPARSE_DATA_BUFFER) olarak saklıyor; Wine içinden yol çözülüyor, Köprü'nün `detect`'i bulamıyordu. Kurucunun `EAX_DISABLE_SYMLINKS=1` seçeneği işe yaramıyor (EAXBA değişkeni kayıt defteri denetiminden sonra 0'a çekiyor). → `Recipe.isInstalled` artık Wine bağlantılarını izliyor (yeni `WineReparsePoint`: göreli/mutlak sembolik bağlantı ve junction, `\??\X:\` `dosdevices` üzerinden; bottle dışına çıkan yol ve döngü reddediliyor). `detect` sürüm klasörüne değil bağlantıya baktığı için EA kendini güncellese de doğru kalır.
- **Tarif:** `rating` opens; Başlat menüsündeki `EA/EA.lnk` gizli (bayraksız `EALauncher`'ı açar, Steam'deki `Steam.lnk` gibi).
- **Uçtan uca:** `PlatformTrialTests` (temiz kök, Köprü'nün kurulum kodu, geliştirme motoru): 18 sn bottle, 36 sn kurulum, `detect: true`; açılışta 520×867 giriş ekranı çizili, 120 sn açık kaldı. Bundan önceki iki tur bu turun ara adımları (bayraksız açılış: boş pencere; `EAX_DISABLE_SYMLINKS`: etkisiz).

Kanıtlar (Burn günlükleri, Wine izi özeti): `~/WineBottles/kopru-platform/ea-kanit/`. Ekran görüntüleri o klasöre kopyalanınca siliniyor (Rockstar notundaki PNG silinmesiyle aynı; kaynağı bilinmiyor).

### Yeni tarif eylemleri (KopruCore)

| Eylem | Ne yapar | Kullanan |
|---|---|---|
| `{"action": "stopPrograms"}` | Bottle'daki bütün Windows programlarını kapatır (`wineserver -k`). Wine çalıştırdığı için `whileRunning`'de tekrarlanmaz. | Battle.net `afterInstall` |
| `{"action": "jsonValues", "file": "<bottle'a göre göreli>", "values": {…}}` | JSON dosyasının üst düzey anahtarlarına değer yazar, ötekileri korur, dosya yoksa oluşturur. Boş dosya boş nesne sayılır, bozuk JSON'da hata. Mutlak yol, `..` ve bottle dışına çıkan yol reddedilir (tarifler depodan da gelebilir). | GOG Galaxy `beforeLaunch` |
| `{"action": "helperProxy", "file": "<bottle'a göre göreli exe>"}` | Yardımcı programı tarif dosyalarındaki aynı adlı aracıyla değiştirir, gerçeği `<ad>_gercek.exe` olur; aracı gerçeğini ek Chromium bayraklarıyla açar (`Tools/cef-araci`). Yardımcı yoksa bir şey yapmaz; program güncelleyip yeni gerçek dosya yazarsa onu kenara alır. Dosya eylemi, `whileRunning`'de tekrarlanır. Yol denetimi `jsonValues`'unkiyle aynı. | Rockstar `beforeLaunch` + `whileRunning` (SocialClubHelper, `--in-process-gpu`) |

Bottle ayarı `wined3dPrograms` (Rockstar: `["Launcher.exe"]`): listedeki programlar DXMT yerine Wine'ın kendi Direct3D'siyle açılır (motor yaması `Tools/motor-yamalari/ntdll-program-basina-wined3d.patch`, ortam değişkeni `KOPRU_WINED3D_EXE`).

Testler: `RecipeTests` (çözme, gidiş-dönüş), `RecipeActionPerformerTests` (`wineserver -k` çağrısı; birleştirme, oluşturma, boş dosya, bozuk JSON, bottle dışı yollar), `HelperProxyTests` (aracı tanıma, değiştirme, güncelleme, eksik yardımcı, `/private` önekli kökte yol denetimi), `EngineTests`/`BottleSettingsTests` (`wined3dPrograms`), `RepositoryCatalogTests` (wined3d programına `renderer=gl`, aracılar derlenmiş), `RecipeInstallerTests` (wineboot mscoree/mshtml'i kapatmıyor), `WineReparsePointTests` (göreli bağlantı, `dosdevices` üzerinden junction, hedefsiz/özniteliksiz girdi, döngü ve bottle dışı).

## Açık noktalar

- Ubisoft, Battle.net ve GOG yalnız giriş ekranına kadar denendi (hesapla giriş, oyun indirme yok); Rockstar'da hesapla giriş, kitaplık ve mağaza denendi, oyun indirme yok (GTA V diskteki boş yerden büyük). Dördünün arayüzü İngilizce açılıyor (Battle.net kurucusuna `--lang=trTR` verilse de).
- Battle.net ve GOG pencereleri sanal masaüstüne girmiyor (ayrı Mac pencereleri; Ubisoft ve Steam giriyor). Nedeni araştırılmadı.
- Rockstar'ın iki motor yaması (program başına wined3d, saat dilimi) geliştirme motorunda ve Release paketinde (yedekler `~/WineBuild/yedek/ntdll.so.dock-adi`, `ntdll.so.wined3d`). GitHub'daki 0.1.0 DMG'sinde saat dilimi yaması yok. Oyunlar (GTA V, RDR2) DXMT'de kalıyor; denenmedi.
- EA App yalnız giriş ekranına kadar denendi; arayüzü İngilizce, penceresi sanal masaüstüne girmiyor (520×867 ayrı Mac penceresi). EA kendini yeniden başlatırsa (`EALauncher` üzerinden) `--in-process-gpu` düşer ve pencere boş kalabilir; gerekirse `helperProxy` ile `EADesktop.exe`'ye aracı konabilir (yol sürüm klasöründe olduğu için aracı bağlantıyı izlemeli). Gecko ve Mono yalnız geliştirme motorunda; Release derlemesi yapılmadı.
- Battle.net kurucusunun açtığı örnek kurulum bitene dek açık kalıyor; taze denemede penceresi görülmedi, ama arayüzde (yavaş makinede) kısa süre görünebilir. Arayüzde denenmedi.
- Tek tıkla kurulum, Durdur ve Tekrar dene arayüzde elle denenmedi (tık gönderilemiyor). Durumlar Debug'da `KOPRU_SAHTE_KURULUM=indiriliyor:epic|hata:<id>` ile görüntülendi; `KOPRU_SAYFA=kur` Debug'ı Program kur'da açar.
