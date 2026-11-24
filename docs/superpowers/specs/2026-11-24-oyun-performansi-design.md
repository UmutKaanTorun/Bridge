# Bridge — Oyun performansı: MetalFX, AVX, uyku engeli, Game Mode

- **Tarih:** 2026-11-24
- **Durum:** Umut tasarımı onayladı (2026-11-24); uygulanmadı.
- **Bağlam:** "Platformu Mac'e uyumlu ve optimize hale getirme" isteğinden oyun performansı parçası. Motor (CrossOver 26.3.0 kaynağı + DXMT 0.80) bunların çoğunu zaten taşıyor; Bridge açmıyordu. Kapsam dışı kalanlar 7. bölümde.

## Özet

| Madde | Bulgu | Yapılacak |
|---|---|---|
| Shader önbelleği | **Zaten açık.** DXMT varsayılan olarak her exe için önbellek tutuyor. | Yok. |
| MetalFX | FPS'ten çok **netlik** kazandırıyor: oyun aynı çözünürlükte çizer, MetalFX Retina'ya büyütür. | Bottle ayarı "Keskin görüntü (MetalFX)", varsayılan kapalı. |
| AVX | `ROSETTA_ADVERTISE_AVX=1` ile Rosetta AVX ve AVX2 bildiriyor (bu Mac'te denendi). | Bottle ayarı "AVX desteği", varsayılan kapalı. |
| Uyku engeli | Wine'da `NtSetThreadExecutionState` taslak; oyun "ekran açık kalsın" dese de macOS'a bir şey iletilmiyor. | Motor yaması 6: çağrıyı IOPMAssertion'a bağla. Her zaman açık. |
| Game Mode | Wine'da Game Mode'a dair hiçbir şey yok. Wine süreçleri paket (`.app`) içinde çalışmadığı için büyük olasılıkla oyun sayılmıyor. | Önce deneme (Aşama 0). Gerekirse motor yaması 7: Dock adı bağlantısını küçük bir `.app` paketine koy. |

## 1. Doğrulanan bilgiler

### Shader önbelleği (yapılacak iş yok)

- DXMT v0.80 `src/dxmt/dxmt_shader_cache.cpp`: önbellek yalnız `DXMT_SHADER_CACHE=0` ise kapanır. Yol `DXMT_SHADER_CACHE_PATH` verilmezse `dxmt/<exe adı>/shaders_<metal sürümü>.db`.
- Göreli yol `src/winemetal/unix/cache.c` `resolve_cache_dir()` ile `confstr(_CS_DARWIN_USER_CACHE_DIR)` altına çözülüyor. Metal'in kendi PSO önbelleği de aynı klasörde (`dxgi.cpp` `InitializeMetalCachePath`, `dxmt/<exe>/com.apple.metal`).
- Bu Mac'te `$(getconf DARWIN_USER_CACHE_DIR)dxmt/` altında `PEAK.exe`, `Among Us.exe`, `Thief Simulator 2 Prologue.exe`, `steamwebhelper.exe` ve başkaları için dolu önbellek klasörleri var.
- Önbellek exe adına göre tutuluyor ve macOS disk sıkışınca bu klasörü temizleyebilir. Şimdilik sorun değil.

### MetalFX

- `src/d3d11/d3d11_swapchain.cpp:1116`: `DXMT_METALFX_SPATIAL_SWAPCHAIN=1` ise ve aygıt `supportsFXSpatialScaler` diyorsa swapchain MetalFX'li kurulur; desteklemiyorsa uyarı yazılır ve normal swapchain'e düşülür.
- Ölçek `d3d11.metalSpatialUpscaleFactor` (satır 142), **varsayılan 2**, en az 1. Bridge'in ayrıca `DXMT_CONFIG` vermesine gerek yok.
- Nasıl çalışıyor (satır 513–528, 583; `dxmt_presenter.cpp:21`): oyunun arka tamponu oyunun istediği boyutta kalır. MetalFX bunu `boyut × ölçek`e büyütür, katmanın `contentsScale`'i de ölçekle çarpılır.
- Bridge'de Wine Retina kipinde değil. Oyun nokta (point) çözünürlüğünde çizer, macOS bunu bugün 2× bulanık büyütüyor. MetalFX 2× ile çıktı tam Retina piksel sayısına denk geliyor: **aynı çizim maliyetinde daha net görüntü.** FPS artışı ancak oyun içinde çözünürlük düşürülürse gelir.
- Retina olmayan ekranda 2× çıktı yeniden küçültülür; boşa GPU harcanır. Ayar açıklaması bunu söyler.
- Yalnız DXMT'den geçen programlarda (DirectX 10/11) etkili. `wined3dPrograms` listesindekiler, DirectX 9 ve 12 etkilenmez.

### AVX

- `/usr/libexec/rosetta/runtime` içinde `ADVERTISE_AVX` dizgisi var.
- Deneme: x86_64 için derlenen küçük bir CPUID programı varsayılanla `AVX=0 AVX2=0`, `ROSETTA_ADVERTISE_AVX=1` ile `AVX=1 AVX2=1` yazdı (macOS 26.6.2, M3).
- Rosetta bunu varsayılan olarak kapalı tutuyor. Çevrilmiş AVX kodu bazı oyunlarda SSE yolundan yavaş olabilir; AVX isteyen oyunlar ise onsuz açılmıyor. Bu yüzden ayar varsayılan olarak kapalı.

### Uyku engeli

- `dlls/ntdll/unix/system.c:4779` `NtSetThreadExecutionState`: yalnız durumu saklıyor, `WARN(... stub, harmless)`.
- `winemac.drv/macdrv_main.c:600–614`: yalnız `SystemParametersInfo(SPI_SETSCREENSAVEACTIVE, FALSE)` bir `PreventUserIdleDisplaySleep` kilidi alıyor. `window.c:1302`: kullanıcı girdisi `IOPMAssertionDeclareUserActivity` çağırıyor.
- `SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED)` kullanan oyunlar (SDL tabanlılar dahil) kumandayla oynanırken ekranın kararmasını engelleyemiyor.
- ntdll'in unix tarafı zaten IOKit'e bağlı: `dlls/ntdll/Makefile.in` `UNIX_LIBS = $(IOKIT_LIBS) …`, `system.c:62–64` IOKit başlıkları.

### Game Mode

- Wine kaynağında (`dlls/winemac.drv`, `loader`) `GameMode`, `LSSupportsGameMode` ya da `LSApplicationCategoryType` geçmiyor.
- Dock adı yaması (`ntdll-dock-adi.patch`) her Windows sürecini yükleyicinin `$TMPDIR/winetemp-…/<ad>` adlı sabit bağlantısından başlatıyor (`create_preloader_link`, `loader.c:649`). Bu dosya bir paketin içinde değil, Info.plist'i yok.
- macOS Game Mode'u tam ekrandaki uygulamanın kategorisine (`public.app-category.*-games`) ya da `LSSupportsGameMode` anahtarına bakarak açar. Wine süreçlerinde bunların hiçbiri yok. **Doğrulanmadı;** Aşama 0'da denenecek.

## 2. Yaklaşım

Ayarlar **bottle başına**, mevcut `BottleSettings` ve Bottle Ayarları penceresinde. Gözden geçirilen öteki yollar:

- **Oyun (exe) başına profil:** Steam bottle'ında oyunları ayırırdı. Ama `ROSETTA_ADVERTISE_AVX` ve `DXMT_METALFX_SPATIAL_SWAPCHAIN` ortam değişkeni; alt süreçlere aynen geçiyor. Exe başına seçim yeni bir ntdll yaması ve yeni bir arayüz ister. Şimdilik gereksiz.
- **Uygulama geneli tek ayar:** En basit yol, ama launcher bottle'ları ile oyun bottle'larını ayıramıyor.

Uyku engeli ve Game Mode kullanıcı ayarı değil, motorun doğru davranışı. Her zaman açık olurlar.

## 3. Bileşenler

### 3.1 KopruCore: `BottleSettings`

```swift
/// DXMT'nin MetalFX uzamsal ölçekleyicisi (2×). Oyun aynı çözünürlükte çizer, çıktı Retina'ya büyütülür.
/// Yalnız DXMT'den geçen programlar (D3D10/11). Eski kopru.json'larda yoktur; nil = kapalı.
public var metalFXUpscale: Bool?
/// Rosetta'nın AVX/AVX2'yi programlara bildirmesi (ROSETTA_ADVERTISE_AVX). nil = kapalı.
public var advertiseAVX: Bool?
```

- `wined3dPrograms` ile aynı desen: isteğe bağlı alan; eski `kopru.json` alansız çözülür. `init`'e varsayılanı `nil` olan iki parametre eklenir; `.default` değişmez.

### 3.2 KopruCore: `Engine.environment`

| Ayar | Açıkken | Kapalıyken |
|---|---|---|
| `metalFXUpscale == true` | `DXMT_METALFX_SPATIAL_SWAPCHAIN=1` | değişken silinir (`nil`) |
| `advertiseAVX == true` | `ROSETTA_ADVERTISE_AVX=1` | değişken silinir (`nil`) |

- Kapalıyken silmek `MTL_HUD_ENABLED` ve `KOPRU_WINED3D_EXE` ile aynı kural: Bridge'in kendi ortamından sızmasın.
- Değişkenler sabit adlarla `Engine`'e eklenir: `metalFXVariable`, `advertiseAVXVariable`.
- Bottle'ın bütün Wine çalıştırmaları (kurulum, açılış, `reg`, `wineserver`) aynı değeri alır. Steam'den açılan oyunlar değişkeni Steam'den miras alır.

### 3.3 Uygulama: Bottle Ayarları penceresi

- `Form`'a **"Performans"** bölümü (`Section`) eklenir:
  - `Toggle("Keskin görüntü (MetalFX)")`, altında açıklama: "DirectX 11 oyunlarını MetalFX ile Retina çözünürlüğe büyütür. Retina olmayan ekranda kapalı bırakın."
  - `Toggle("AVX desteği")`, altında açıklama: "AVX isteyen oyunlar için. Bazı oyunlar yavaşlayabilir."
  - Bu ikisinden biri kayıtlı değerden farklıysa: "Açık programlar yeniden açılınca geçerli olur." (MSync'teki gibi programlar kapatılmaz; bu değerlerin süreçler arasında aynı olması gerekmiyor.)
- MSync ve FPS göstergesi bulundukları yerde kalır. Pencere yüksekliği yeni bölüme göre büyütülür.
- Kaydetme, pencerede olmayan alanları (ör. `wined3dPrograms`) yine korur.

### 3.4 Motor yaması 6: `ntdll-uyku-engeli.patch`

`dlls/ntdll/unix/system.c` `NtSetThreadExecutionState`, `#ifdef __APPLE__`:

- Mevcut durum saklama ve `old_state` dönüşü aynen kalır.
- `ES_CONTINUOUS` varsa süreç genelinde iki kilit yönetilir:
  - `ES_DISPLAY_REQUIRED` → `kIOPMAssertionTypePreventUserIdleDisplaySleep` (yoksa alınır; yeni durumda bayrak yoksa bırakılır).
  - `ES_SYSTEM_REQUIRED` ya da `ES_AWAYMODE_REQUIRED` → `kIOPMAssertionTypePreventUserIdleSystemSleep`.
- `ES_CONTINUOUS` yoksa ve `ES_DISPLAY_REQUIRED`/`ES_SYSTEM_REQUIRED` varsa (tek seferlik): `IOPMAssertionDeclareUserActivity(…, kIOPMUserActiveLocal, …)` boşta kalma sayacını sıfırlar.
- Kilitler bir `pthread_mutex` ile korunur. Kilit adı: `"Wine: SetThreadExecutionState"`; `pmset -g assertions`'ta bu adla görünür.
- Süreç kapanınca macOS kilitleri kendisi bırakır.
- **Bilinen sadeleştirme:** Windows'ta `ES_CONTINUOUS` durumu iş parçacığı başına tutulur. Yama süreç geneli tutuyor: bir iş parçacığının "artık gerekmez" çağrısı ötekinin isteğini de kaldırır. Oyunlarda bu çağrı neredeyse hep tek bir iş parçacığından gelir.
- Derleme: `~/WineBuild/yapi-26.3.0`'da `arch -x86_64 make dlls/ntdll/ntdll.so`. Motora önce yanına kopyalanıp sonra `mv` ile konur (BENIOKU kuralı). `system.c`'ye `#include <IOKit/pwr_mgt/IOPMLib.h>` eklenir.

### 3.5 Aşama 0 ve motor yaması 7: Game Mode

**Aşama 0, deneme (önce bu):**

1. PEAK'i (Steam bottle'ı) Bridge'den açıp tam ekrana al. Menü çubuğunda Game Mode simgesi çıkıyor mu, `gamepolicyd` günlüğünde süreç için karar var mı, bak.
   - Çıkıyorsa yama 7 gerekmez; sonuç buraya yazılır.
2. Çıkmıyorsa: motorun APFS kopyasında (`cp -c`) aşağıdaki yamanın ilk hâlini derle. `KOPRU_MOTOR` ile o kopyadan aynı denemeyi yap.
   - Game Mode açılıyorsa yama 7'ye geç.
   - Açılmıyorsa madde düşer; nedeni buraya yazılır.

**Yama 7, `ntdll-game-mode.patch`** (`ntdll-dock-adi.patch`'in üzerine, `loader.c`):

- `KOPRU_APP_NAME` varken `create_preloader_link` bağlantıyı `…/winetemp-…/<ad>.app/Contents/MacOS/<ad>` olarak kurar (önce sabit bağlantı, olmazsa sembolik bağlantı; mevcut kural). Yanına `Contents/Info.plist` yazar:
  - `CFBundleExecutable` = `<ad>`, `CFBundleName` = `<ad>`, `CFBundlePackageType` = `APPL`
  - `CFBundleIdentifier` = `dev.kopru.wine.<ad'ın harf-rakam hâli>`
  - `LSApplicationCategoryType` = `public.app-category.games`, `LSSupportsGameMode` = `true`
  - `NSHighResolutionCapable` = `true`: paketsiz süreçler bugün yüksek çözünürlüklü sayılıyor; anahtar olmazsa AppKit pencereyi düşük çözünürlük kipinde açabilir ve MetalFX çıktısı değişir.
  - `NSMicrophoneUsageDescription`: Bridge'inkiyle aynı metin (commit `13312c8`: bu açıklama olmadan mikrofon açan oyun donuyordu).
- Paket zaten varsa yeniden kullanılır (bugünkü "bağlantı varsa kullan" kuralı).
- `KOPRU_APP_NAME` yoksa davranış eskisiyle aynı.
- **Riskler (Aşama 0'da ve sonra denenecek):**
  - TCC: mikrofon izni hâlâ Bridge'e mi yazılıyor? Süreci Bridge başlattığı için öyle beklenir. PEAK'in sesli sohbeti açılmalı.
  - Dock: ad ve simge aynı kalmalı. Rockstar'da tek simge kalmalı (`winemac-dock-gizle.patch` exe adına bakıyor, paketten etkilenmemeli).
  - LaunchServices: geçici paketler kayıt veritabanına giriyor mu (`lsregister -dump | grep winetemp`)? Klasör yolu sabit olduğu için kayıtların birikmemesi beklenir.
  - Steam'in kendisi de "oyun" kategorisinde olur. Game Mode yalnız tam ekranda devreye girdiği için pencereli Steam'i etkilememeli.

## 4. Test

**Birim testleri (`swift test --package-path KopruCore`):**

- `EngineTests`:
  - `metalFXUpscale: true` → `DXMT_METALFX_SPATIAL_SWAPCHAIN=1`.
  - `false` ve `nil` → değişken yok, `base`'de olsa bile.
  - `advertiseAVX` için aynı üç durum.
- `BottleSettings` çözümleme:
  - `metalFXUpscale`/`advertiseAVX` alanı olmayan eski `kopru.json` (bu Mac'teki Steam bottle'ınınki gibi, `virtualDesktop` dahil) hatasız çözülür, iki alan `nil`.
  - Alanlı JSON gidip gelir.

**Elle:**

- **MetalFX:** PEAK ya da Thief Simulator 2 Prologue, FPS göstergesi açık. Kapalı ve açık ekran görüntüleri karşılaştırılır. Önce `DXMT_LOG_LEVEL=info` ile günlükte MetalFX'li swapchain'in kurulduğu görülür. Steam ve Epic arayüzü (CEF de DXMT'den geçiyor) bozulmamalı.
- **AVX:** mingw ile derlenen küçük bir Windows programı bottle'da CPUID'yi ve `IsProcessorFeaturePresent(PF_AVX2_INSTRUCTIONS_AVAILABLE)` sonucunu yazar. Ayar kapalıyken 0, açıkken 1 beklenir.
- **Uyku engeli:** küçük bir Windows programı `SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED)` çağırıp bekler. `pmset -g assertions`'ta `PreventUserIdleDisplaySleep` görünmeli. `ES_CONTINUOUS` ile temizleyince ve program kapanınca kaybolmalı. Ardından PEAK açıkken aynı denetim yapılır (Unity'nin bu çağrıyı yapıp yapmadığı not edilir).
- **Game Mode:** Aşama 0'daki denetim, yama 7'li motorla.
- **Gerileme:**
  - Steam, Epic, Rockstar açılmalı; Rockstar'da Dock'ta tek simge kalmalı.
  - PEAK'in sesli sohbeti donmadan açılmalı.
  - Wine süreçlerinin Dock adı aynı kalmalı.

## 5. Belgeler

- `Tools/motor-yamalari/BENIOKU.md`: yamalar 6 ve 7 tabloya ve derleme notlarına eklenir (yama 7 yalnız Aşama 0 olumluysa).
- `README.md` "Özellikler": MetalFX, AVX ve (çıkarsa) Game Mode tek satırla eklenir.

## 6. İş sırası

1. Aşama 0 (Game Mode denemesi). Sonucu yama 7'nin yapılıp yapılmayacağını belirler.
2. `BottleSettings` + `Engine.environment` + birim testleri.
3. Bottle Ayarları penceresi.
4. Yama 6 (uyku engeli) + elle deneme.
5. Yama 7 (Aşama 0 olumluysa) + elle deneme.
6. Gerileme denemeleri, BENIOKU ve README.

## 7. Kapsam dışı

- **DirectX 12 (D3DMetal):** Apple'ın Game Porting Toolkit'inden; kapalı kaynak. Bridge'le dağıtılıp dağıtılamayacağı ayrıca incelenmeli.
- **DirectX 9 hızı:** wined3d + OpenGL yolu; ayrı iş.
- **DLSS → MetalFX zamansal ölçekleme** (`DXMT_ENABLE_NVEXT` + `nvngx.dll`): motorda `nvngx.dll` yok.
- Oyun başına profiller, Retina kipi (`RetinaMode`), kare hızı sınırı (`d3d11.preferredMaxFrameRate`).
- Intel Mac ve daha eski macOS desteği, notarization.
