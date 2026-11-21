# Köprü — Rockstar Games Launcher: motor düzeyinde çözüm seçenekleri

- **Tarih:** 2026-11-21
- **Durum:** Umut C yolunu onayladı (2026-11-21); uygulandı, bkz. "4. Uygulama". A ve B denemeleri motorun ve bottle'ın APFS kopyalarında yapıldı.
- **Bağlam:** [`2026-11-21-platform-kur-design.md`](2026-11-21-platform-kur-design.md) → "Rockstar Games Launcher — düzelmedi". Launcher'ın arayüzünü Wine'ın yerleşik `d2d1.dll`'i çiziyor; d2d1 ilk çizimde `ID3D11DeviceContext1::SwapDeviceContextState` çağırıyor, DXMT 0.80 bunu uygulamıyor ve süreci `abort()` ile kapatıyor.

## Özet

| | Sonuç |
|---|---|
| Daha yeni DXMT | Sürüm yok (son sürüm v0.80, 2026-04-23). Ana dalda `SwapDeviceContextState` var (Ekim 2026), ama tek başına yetmiyor: arkasından ikinci bir eksik çıkıyor. |
| DXMT'ye yama (denendi) | Launcher **"Initializing engine"i geçti**, 1 sn sonra d2d1'de erişim ihlali: DXMT'de GDI uyumlu yüzey (`IDXGISurface1::GetDC`) yok. Bu parça DXMT ana dalında da "TODO". |
| wined3d (denendi) | OpenGL arka ucuyla **Launcher açıldı**: kendi ekranı doğru çizildi, Social Club'ı kendisi indirip kurdu, "Rockstar Games - Sign In" penceresi açıldı. Pencere beyaz kalıyor (Social Club'ın CEF GPU süreci çöküyor). |
| Öneri | **Program başına grafik arka ucu**: Launcher wined3d (OpenGL) ile, oyunlar ve geri kalan her şey DXMT ile. Küçük bir ntdll yaması + tarif alanı, ~1 gün. Social Club'ın beyaz penceresi ayrı iş. |
| Uygulama (4. bölüm) | Yapıldı ve Köprü'nün açılış akışıyla denendi: Launcher kendi ekranını çiziyor, Social Club'ı kuruyor, Sign In penceresini açıyor; `SocialClubHelper.exe` DXMT'de kalıyor. Kurulumdaki dil penceresi de düzeldi: tarif `/quiet` yerine Rockstar'ın kendi sessiz argümanı `/s /f`'yi kullanıyor. |
| Social Club (5. bölüm) | **Düzeldi:** giriş penceresi çiziliyor. Neden: CEF'in ayrı GPU süreci tarayıcı sürecinin penceresine swapchain açamıyor (DXMT `cross-process swapchain not supported`). Çözüm: yeni `helperProxy` tarif eylemi `SocialClubHelper.exe`'nin önüne `--in-process-gpu` ekleyen aracıyı koyuyor. Tarif notu "opens". |

## 1. DXMT'nin yeni sürümü

- GitHub sürümleri: v0.80 (2026-04-23) en yenisi; sonrasında 408 commit var, sürüm yok.
- `e186434` "feat(d3d11): implement `SwapDeviceContextState()`" (Feifan He, CodeWeavers; 2026-10-05). Bağlamın tüm durumunu (`D3D11ContextState`) `MTLD3D11DeviceContextState` nesnesine taşıyıp değiştiriyor. `CreateDeviceContextState` v0.80'de zaten vardı (boş nesne döndürüyor).
- `a148782` "feat(d3d11, dxgi): implement dxgi surface" (2026-10-06): dokular artık `IDXGISurface1` veriyor, **ama** `GetDC`/`ReleaseDC` `// TODO(gdi-surface)` ile `DXGI_ERROR_INVALID_CALL` döndürüyor (commit iletisi: "GDI surface is not implemented").
- Yani DXMT'nin ana dalı bile d2d1'in DC render target'ını çizemez: çökme yerine boş pencere olur.

## 2. Deneme: v0.80 + `SwapDeviceContextState`

**Derleme (25 sn, yalnız 64 bit `d3d11.dll`):** `e186434` v0.80'e iki önemsiz çakışmayla uygulandı (çakışan kısım sonradan eklenen `AcquireSync`/`ReleaseSync`; alınmadı). Yalnız `ninja src/d3d11/d3d11.dll` derlendi; PE tarafı LLVM istemiyor (`-Dnative_llvm_path` boş bir klasöre). İki engel:

- Xcode 26'da Metal araç zinciri ayrı indiriliyor ve kurulu değil (`xcodebuild -downloadComponent MetalToolchain`). `libdxmt.a`'nın gömdüğü `dxmt_command.metallib` v0.80'in kendi `d3d11.dll`'inden çıkarıldı (dosya içi 0x276060, 152 339 bayt; kaynak değişmediği için aynı bayt).
- Homebrew mingw-w64 (GCC 16) `com_guid.cpp`'de eksik `#include <iomanip>` istedi. Resmi sürüm llvm-mingw 20251216 ile derleniyor; gerçek motor için o kullanılmalı (deneme için GCC yeterli oldu, içe aktarımlar resmi DLL'le aynı).
- Sonra `winebuild --builtin` ile Wine yerleşiği işaretlendi.

**Deneme:** motorun APFS kopyasında (`cp -c`) yalnız `x86_64-windows/d3d11.dll` değiştirildi, Rockstar bottle'ının kopyası `KOPRU_MOTOR` + `KOPRU_TARIF_DENE_KOK` ile `PlatformTrialTests`'te açıldı.

- `UNIMPLEMENTED SwapDeviceContextState` artık yok. Launcher'ın günlüğü "Initializing engine / group 1"den sonra devam ediyor: kendini güncelleme "Up-to-date", sistem tepsisi, sürüm denetimi.
- 1,3 sn sonra `Exception: 0xc0000005`, yığında d2d1 → Launcher'ın pencere yordamı (500×400 beyaz pencere görünüp kapanıyor, çıkış kodu 0).
- Neden: d2d1'in `d2d_dc_render_target_BindDC`'si dokudan `IDXGISurface1` istiyor ve sonucu denetlemiyor; DXMT 0.80 bu arabirimi tanımıyor (Köprü günlüğü: `D3D11Resource(tex2d): Unknown interface query 4ae63092-…` = `IDXGISurface1`). `EndDraw`'da `IDXGISurface1_GetDC(NULL, …)` çağrılıyor.

## 3. Deneme: wined3d (Wine'ın kendi d3d11/dxgi/d3d10core'u)

Motorun ikinci APFS kopyasında `lib/wine/{x86_64,i386}-windows`'a `orijinal-grafik/`'teki üç DLL kondu (bütün bottle wined3d).

- **Varsayılan ayarla başarısız:** CrossOver motoru wined3d'yi Vulkan (MoltenVK) ile çalıştırıyor (`Using the Vulkan renderer for d3d10/11 applications`). MoltenVK'da geometri gölgelendiricisi olmadığı için D3D 10_0 verilemiyor (`None of the requested D3D feature levels is supported`), Launcher "failed to initialize!" iletişim kutusu gösteriyor.
- **`WINE_D3D_CONFIG=renderer=gl` ile çalışıyor:** Launcher'ın d2d1 ekranı doğru çiziliyor ("Connecting to Rockstar Games Services", Rockstar logosu), Wine'ın `dxgi_surface_GetDC`'si d2d1'e hizmet veriyor. Launcher Social Club'ı (`Redistributables\SocialClub\Social-Club-Setup.exe`) kendisi kurdu ve 45. sn'de "Rockstar Games - Sign In" (700×800) penceresi açıldı.
- **Social Club beyaz:** Sign In penceresi 2 dk beyaz kaldı. CEF'in tarayıcı süreci Launcher değil, Launcher'ın sabit bayraklarla açtığı `SocialClubHelper.exe`; Launcher'a verilen `--in-process-gpu` ona geçmiyor (izde görüldü, etkisiz). Çöken `--type=gpu-process`: libcef içinde `int3` (büyük olasılıkla bir CHECK); GPU süreci 3 kez yeniden başlayıp vazgeçiliyor. Bu GPU süreci wined3d'de olduğu için; DXMT'de ise Ubisoft'taki "cross-process swapchain" sorunu beklenir ve bayrak verilemiyor.

## Üç yolun maliyeti ve riski

| Yol | İş | Risk | Rockstar'a etkisi |
|---|---|---|---|
| **A. DXMT'yi yamamak** | `e186434` (hazır, derlendi) + `a148782` (dxgi yüzeyi, 360 satır, v0.80'e çakışmalı) + **GDI yüzeyini yazmak** (`GetDC`/`ReleaseDC`; DXVK'nın `d3d11_gdi.cpp`'si ~200 satır örnek: geri okuma dokusu + `D3DKMTCreateDCFromMemory`, `ReleaseDC`'de `UpdateSubresource`). 32 bit de derlenmeli; llvm-mingw ve Metal araç zinciri kurulmalı. **2–4 gün.** | Orta-yüksek: DXMT iç yapısına dokunuyor; her DXMT güncellemesinde yeniden uygulanmalı (yukarı akış "TODO(gdi-surface)"ı kapatana dek). Henüz uçtan uca denenmedi. | Her şey DXMT'de kalır. Launcher'dan sonraki adımlar (Social Club CEF) yine ayrı. |
| **B. Wine'ın d2d1'ini yamamak** | `dc_render_target.c`: `GetDC` olmazsa hazırlama dokusuna kopyala + `Map` + `SetDIBitsToDevice` (~60 satır). `SwapDeviceContextState` için ya A'daki DXMT commit'i ya da d2d1'de çizimin değiştirdiği ~12 durumu elle kaydet/geri yükle (~80 satır). `d2d1.dll` `~/WineBuild/yapi-26.3.0`'da `make -C dlls/d2d1` ile derlenir. **~1 gün.** | Düşük-orta: yalnız d2d1, yalnız genel D3D11 API'si. Wine güncellemelerinde yama taşınmalı; her karede CPU'ya geri okuma (Launcher'ın küçük ekranında önemsiz). Denenmedi; d2d1'in DXMT'de başka bir eksiğe takılmayacağı bilinmiyor. | DXMT'de kalır. d2d1 DC render target kullanan başka programları da düzeltir. |
| **C. Program başına wined3d** | Motor zaten `orijinal-grafik/` taşıyor (Release'te çıkarılıyordu; 3 MB, pakete girmeli). Seçim mekanizması: CrossOver'ın ntdll'inde zaten `prepend_dll_path()` var (CW Hack 24067; DLL yolunu motor klasörünün **önüne** koyar, CrossOver bunu kapalı `cxcompatdb.so`'su ile program başına kullanıyor, bizde o dosya yok). Köprü yaması: ntdll ana programın adını öğrendikten sonra (`set_load_order_app_name`'in hemen ardından) `KOPRU_WINED3D_EXE` listesindeki bir adla eşleşirse `prepend_dll_path("<motor>/orijinal-grafik")`. wined3d ayarı tarifle: `HKCU\Software\Wine\AppDefaults\Launcher.exe\Direct3D\renderer = gl`. KopruCore'da tarif alanı (ör. `"wined3d": ["Launcher.exe", "LauncherPatcher.exe"]`) ve ortam değişkeni. **~1 gün.** | Düşük: Wine'ın kendi d3d11'i d2d1'i zaten destekliyor (denendi). ntdll yaması küçük ve `ntdll-dock-adi.patch` ile aynı yerde. wined3d+OpenGL macOS'ta oyun için yavaş/yetersiz; bu yüzden **bütün bottle değil, yalnız listedeki programlar**. | Launcher açılıyor (denendi). Oyunlar (GTA V, RDR2) DXMT'de kalır. |

`WINEDLLPATH` işe yaramaz: Wine motor klasörünü her zaman önce arıyor, `WINEDLLPATH` arkaya ekleniyor (`set_dll_path`). Önceki oturumdaki `AppDefaults\DllOverrides` + system32 denemesinin tutmama nedeni de bu (yerleşikler yalnız DLL yollarından yükleniyor).

## Öneri

1. **C'yi yap** (program başına wined3d). Rockstar için denenmiş tek yol; Launcher'ı oyunlardan ayırıyor; ileride başka DXMT eksiklerinde (d2d1, GDI birlikte çalışması) tarifle kullanılabilecek genel bir araç. CrossOver'ın kendi yaklaşımıyla aynı (program başına DLL yolu).
2. **A'yı DXMT güncellemesine bırak:** DXMT'nin `SwapDeviceContextState` + GDI yüzeyini içeren bir sürümü çıkınca Rockstar'ı tarifte DXMT'ye döndürmeyi dene. Yaması ve derlenmiş DLL paylaşılan not klasöründe (aşağıda); tek başına motora konmamalı (Launcher yine çöker, yalnız yeri değişir).
3. **B**, program başına seçim istenmezse yedek yol.

Sonraki adım (C'den sonra): Social Club'ın Sign In penceresi. Çözüldü, bkz. 5. bölüm (DirectComposition ipucu yanlış çıktı; asıl neden süreçler arası swapchain).

## 4. Uygulama: program başına wined3d

- **Motor:** [`Tools/motor-yamalari/ntdll-program-basina-wined3d.patch`](../../../Tools/motor-yamalari/ntdll-program-basina-wined3d.patch) (`ntdll-dock-adi.patch`'ten sonra, `patch -p1`). `start_main_thread`'de `set_load_order_app_name`'in hemen ardından `kopru_wined3d_for_app(main_wargv[0])`: exe adı (büyük/küçük harf duyarsız) `KOPRU_WINED3D_EXE`'deki virgülle ayrılmış adlardan biriyse `realpath(<dll_dir>/../../orijinal-grafik)` `prepend_dll_path()` ile arama yolunun başına konur; klasör yoksa uyarı yazılır ve program DXMT'de kalır. Değişken yoksa davranış eskisiyle aynı. Derleme: `~/WineBuild/yapi-26.3.0`'da `make dlls/ntdll/ntdll.so` (2 sn), motora `lib/wine/x86_64-unix/ntdll.so` olarak kopyalanır. 32 bit programlar WoW64'te aynı ntdll'den geçer, `orijinal-grafik/i386-windows` kullanılır.
- **KopruCore:** `BottleSettings.wined3dPrograms: [String]?` (eski `kopru.json` dosyaları alansız çözülür). `Engine.environment` bunu `KOPRU_WINED3D_EXE`'ye yazar; boşsa değişkeni siler (Köprü'nün kendi ortamından sızmasın). Virgüllü ya da boş adlar atlanır. Bottle'ın bütün Wine çalıştırmaları (kurulum, açılış, `reg`) aynı değeri alır; alt süreçler (ör. `SocialClubHelper.exe`) değişkeni miras alır ama yalnız kendi adı listedeyse wined3d'ye geçer.
- **Tarif:** `rockstar.json` → `bottle.settings.wined3dPrograms = ["Launcher.exe"]`, `afterInstall`'da `HKCU\Software\Wine\AppDefaults\Launcher.exe\Direct3D` `renderer=gl`. `RepositoryCatalogTests.wined3dProgramsAreSetToOpenGL` her wined3d programı için bu kaydın tarifte olduğunu denetler. `LauncherPatcher.exe` listede değil: izde hiçbir D3D DLL'i yüklemiyor.
- **Uygulama:** Bottle Ayarları penceresi kaydederken pencerede olmayan alanları (bu liste) korur.
- **Paket:** `Scripts/bundle-engine.sh` artık `orijinal-grafik/`'i dışarıda bırakmıyor; motorda yoksa Release derlemesi hata verir.
- **Geliştirme motoru:** yamalı `ntdll.so` `~/WineEngines/WineCX26.3.0-DXMT0.80/lib/wine/x86_64-unix/`'e kondu (önceki: `~/WineBuild/yedek/ntdll.so.dock-adi`). Değişken yokken davranış aynı. Yama kaynak ağacına da uygulandı (`~/WineBuild/kaynak-26.3.0`), `kur.sh` yeniden çalıştırılırsa korunur.

### Deneme sonuçları

- **Motor kopyasında, elle (`KOPRU_WINED3D_EXE=Launcher.exe`, `WINEDEBUG=+pid,+loaddll`):** iki `launcher.exe` süreci `d3d11`, `dxgi`, `wined3d` yükledi, `winemetal` yüklemedi. `SocialClubHelper.exe`'nin GPU süreci `winemetal` yükledi (DXMT). `LauncherPatcher.exe` D3D yüklemiyor. Wine d3d11'in `SwapDeviceContextState` için yalnız `fixme` yazıyor, çökme yok.
- **Köprü'nün açılış akışıyla** (`PlatformTrialTests`, `KOPRU_TARIF_DENE_KUR=0`, kurulu deneme bottle'ının kopyası, `kopru.json`'a `wined3dPrograms`, tarifin `renderer=gl` kaydı): +15–45 sn Launcher penceresi "Connecting to Rockstar Games Services" (doğru çizilmiş), +60 sn "Rockstar Games - Sign In" (700×800). 120 sn boyunca çökme yok, çıkış kodu 0.
- **Sign In beyaz kalıyordu.** wined3d'de (önceki deneme) CEF GPU süreci `int3` ile çöküyordu; DXMT'de çökmüyor. O sırada `DCompositionCreateDevice3` taslağı neden sanıldı; asıl neden süreçler arası swapchain çıktı (5. bölüm, düzeldi).
- **Kurulum programı dil soruyordu (düzeldi):** temiz bottle'da `/quiet` ile kurulum "Language select" penceresinde bekliyordu. Yamasız asıl motorda ve değişken olmadan da aynıydı, yani motordan bağımsız.
  - Kök neden: Rockstar'ın kurulum programı `/quiet`'i tanımıyor. Kendi günlüğü (`C:\ProgramData\Rockstar Games\Launcher\installer_log.txt`) `/quiet`, `/silent` ve İngilizce yerel ayarla da "Normal install mode" yazıyor. İlk deneme bottle'ında `Silent=0`, `Language=en-US` vardı: o kurulum elle onaylanmıştı.
  - Elenenler: `/silent`, `-language en-US`, `Language=en-US LanguageSet=1` (WiX Burn değişkenleri), kayıt defterine önceden `Language=en-US`, `LANG=en_US.UTF-8`.
  - Çözüm: Rockstar'ın 1.0.105.2705 güncelleme notundaki sessiz kurulum argümanı **`/s /f`**. Temiz bottle'da 15 sn içinde penceresiz kuruluyor; dosyalar elle kurulumla birebir aynı (100 MB), kısayollar oluşuyor, kayıt defterinde `Silent=1`, `Language=""`. Tarifin `installer.arguments`'ı `["/s", "/f"]`.

## 5. Social Club giriş penceresi (düzeldi)

**Kök neden (izle doğrulandı):**
- Sign In penceresini Launcher değil SocialClubHelper'ın tarayıcı süreci oluşturuyor (`+win` izi: `WIN_CreateWindowEx L"Rockstar Games - Sign In"` 0x24c'de). Bu süreç D3D yüklemiyor; CEF pencere modunda.
- İçeriği ayrı `--type=gpu-process` DXMT ile çiziyor ve swapchain'i tarayıcı sürecinin penceresine açamıyor: DXMT günlüğünde `CreateSwapChain: cross-process swapchain not supported yet`.
- Steam (siyah pencere), Ubisoft ve Battle.net'teki sorunun aynısı.

**Denenen ve elenen:**
- `-scDisableGpu` (Social Club'ın kendi parametresi; Launcher'dan geçiyor, CEF'e `--disable-gpu --disable-gpu-compositing` veriyor): swapchain hatası gidiyor ama pencere yine beyaz; yazılımla çizimde de çizim başka süreçten geliyor.
- `SocialClubHelper.exe`'yi de wined3d'ye almak: önceki denemede GPU süreci `int3` ile çöküyordu.
- Social Club'ın parametreleri (`scDisableGpu`, `scEnableGpu`, `scNoSoftwareRasterizer`, `scEnableMsaa` vb.) arasında süreç içi GPU yok; Launcher'a verilen Chromium bayrakları SocialClubHelper'a geçmiyor.

**Çözüm:** `SocialClubHelper.exe` → `SocialClubHelper_gercek.exe`. Yerine konan aracı, programın argümanlarının sonuna `--in-process-gpu` ekleyip gerçeğini açar (Steam'in `steamwebhelper` aracısıyla aynı desen).
- Aracı: [`Tools/cef-araci/araci.c`](../../../Tools/cef-araci/araci.c). Gerçek dosya adı ve bayraklar derlemede verilir; [`derle.sh`](../../../Tools/cef-araci/derle.sh) → `Resources/RecipeFiles/rockstar/SocialClubHelper.exe` (17 KB).
- KopruCore: yeni genel tarif eylemi `helperProxy(file:)` ([`HelperProxy.swift`](../../../KopruCore/Sources/KopruCore/HelperProxy.swift)). Bottle'a göre göreli yardımcıyı tarif dosyalarındaki aynı adlı aracıyla değiştirir. Aracıyı içindeki UTF-16 gerçek dosya adından tanır. Program kendini güncelleyip yeni gerçek dosya yazarsa onu kenara alır. Yardımcı henüz yoksa bir şey yapmaz. Dosya eylemi olduğu için `whileRunning`'de saniyede bir uygulanabilir. Steam'in `SteamWebHelperProxy`'sine dokunulmadı (boyut dolgusu Steam'e özgü).
- Tarif: `beforeLaunch` ve `whileRunning`'de `helperProxy` (`drive_c/Program Files/Rockstar Games/Social Club/SocialClubHelper.exe`). Social Club'ı Launcher ilk açılışta kendisi kurduğu için `whileRunning` gerekli. Not "opens", vurgular eklendi. (Normal kipte kurulum programı sonunda Launcher'ı kendisi açıyordu; sessiz `/s /f` kipinde açmıyor, yalnız `RockstarService` ve VC++ kurulumları çalışıyor. Bu yüzden Battle.net'teki gibi `stopPrograms` gerekmedi.)
- Launcher'ın sürüm denetimi yalnız `socialclub.dll`'e bakıyor (`launcher.log`: "Checking version: …socialclub.dll"), aracı onu bozmuyor.
- Yan düzeltme: `JSONFileValues.resolve` (jsonValues ve helperProxy'nin ortak yol denetimi) `/private/tmp` gibi bağlantılı köklerde var olmayan dosyayı bottle dışı sanıyordu: var olan kök standartlaşırken `/private`'ı kaybediyor, dosya kaybetmiyordu. Yol artık standartlaşmış kökten türetiliyor; test: `HelperProxyTests.pathResolutionToleratesPrivatePrefix`.
- `PlatformTrialTests` artık uygulama gibi `whileRunning` korumasını da çalıştırıyor.

**Deneme (geliştirme motoru, Köprü'nün açılış akışı, kurulu deneme bottle'ının taze kopyası):**
- İlk açılış (Social Club yok): Launcher Social Club'ı kurdu, koruma aracıyı 14:55:07'de koydu, Launcher SocialClubHelper'ı 14:55:12'de açtı. +60 sn'den 150 sn'ye kadar giriş ekranı çizili (Rockstar logosu, Email/Password, Sign in, Create a new account).
- İkinci açılış: `beforeLaunch` hatasız, giriş ekranı +30 sn'de.
- **Sıfırdan, Köprü'nün kurulum + açılış akışıyla** (`PlatformTrialTests`, temiz kök, `/s /f`): indirme 1 sn, kurulum 11 sn, `afterInstall` 1 sn (toplam 30 sn, detect tamam). Açılışta +15/45 sn Launcher ekranı, +60 sn'den sonuna kadar giriş ekranı çizili, dil sorulmadı (arayüz İngilizce). İki kez tekrarlandı.
- Giriş yapmak ve oyun indirmek denenmedi (hesap gerekiyor).

## Deneme düzeni (yeniden üretmek için)

- Motor kopyası: `cp -cRp ~/WineEngines/WineCX26.3.0-DXMT0.80 <kopya>`; DXMT için `lib/wine/x86_64-windows/d3d11.dll` değiştirilir; wined3d için `orijinal-grafik/{x86_64,i386}-windows/*.dll` `lib/wine/…`'ya kopyalanır.
- Bottle kopyası: `cp -cRp ~/WineBottles/kopru-platform/AppSupport/Bottles/Rockstar-Games-Launcher <kök>/AppSupport/Bottles/`.
- Çalıştırma (`KopruCore` içinde): `WINE_D3D_CONFIG=renderer=gl KOPRU_MOTOR=<kopya> KOPRU_TARIF_DENE=rockstar KOPRU_TARIF_DENE_KUR=0 KOPRU_TARIF_DENE_KOK=<kök> KOPRU_TARIF_DENE_SN=120 swift test --filter PlatformTrialTests`. `Engine.environment` ortamı geçirdiği için `WINE_D3D_CONFIG` Wine'a ulaşıyor.
- Launcher günlüğü: `drive_c/users/crossover/AppData/Local/Rockstar Games/Launcher/CrashLogs/launcher.log`.
- Yamalar, derlenmiş `d3d11.dll` (SHA-256 `c7358d5b…8464`), ekran görüntüleri ve günlük: `~/Library/Application Support/Claude/side-session-notes/local_3bbcd428-9ec0-400d-b469-ba4c6d334702/`.
