# Oyun Performansı Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Amaç:** Bridge'de oyunlar için dört şey: bottle başına MetalFX (keskin görüntü) ve Rosetta AVX ayarı; oyun istediğinde ekranın kararmaması (motor yaması 6); deneme olumluysa macOS Game Mode (motor yaması 7).

**Mimari:** MetalFX ve AVX birer ortam değişkeni. `BottleSettings` → `Engine.environment` yolundan Wine'a geçer, alt süreçler (Steam'den açılan oyunlar) miras alır. Uyku engeli ve Game Mode, Wine'ın ntdll'ine iki yeni Köprü yamasıyla gelir (`Tools/motor-yamalari/`). Motor `~/WineBuild` altında derlenir, geliştirme motoruna kopyalanır, Release derlemesi motoru pakete alır.

**Teknolojiler:** Swift 6, SwiftUI, Swift Testing, C (Wine ntdll, IOKit/IOPMLib), mingw-w64 (deneme programları), XcodeGen + xcodebuild.

**Spec:** `docs/superpowers/specs/2026-11-24-oyun-performansi-design.md`

## Genel Kısıtlar

- Depo kökü: `/Users/umuttorun/Desktop/Apps/Kopru`. Komutlar aksi yazmadıkça depo kökünden çalıştırılır.
- Kısaltmalar (her görevde aynı):
  - `W=~/WineBuild/kaynak-26.3.0/sources/wine` (Wine kaynak ağacı; Köprü yamaları 1–5 uygulanmış durumda)
  - `OUT=~/WineBuild/yapi-26.3.0` (derleme klasörü)
  - `ENG=~/WineEngines/WineCX26.3.0-DXMT0.80` (geliştirme motoru)
  - `SCRATCH=/private/tmp/claude-501/-Users-umuttorun--claude-spares-spare-jE9udU/ec369584-b972-40bf-abd3-6a1000db3de6/scratchpad` (geçici dosyalar)
- ntdll derleme komutu (2 sn):
  ```bash
  cd ~/WineBuild/yapi-26.3.0 && arch -x86_64 /bin/zsh -c 'export PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/opt/flex/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"; make dlls/ntdll/ntdll.so'
  ```
- Motordaki dosya yerinde üzerine yazılmaz: önce `<ad>.yeni` olarak yanına kopyalanır, sonra `mv` ile değiştirilir. Değiştirmeden önce eski hâli `~/WineBuild/yedek/`'e alınır.
- Wine süreçleri açıkken aynı bottle'a farklı bir motorla girilmez, motordaki `ntdll.so` da değiştirilmez. Önce Bridge (hem `/Applications/Bridge.app` hem Debug) kapatılır, sonra Steam bottle'ı durdurulur ve hiçbir wineserver kalmadığı denetlenir:
  ```bash
  WINEPREFIX="$HOME/Library/Application Support/Kopru/Bottles/Steam" ~/WineEngines/WineCX26.3.0-DXMT0.80/bin/wineserver -k 2>/dev/null; sleep 2; pgrep -fl wineserver || echo "wine kapalı"
  ```
  Beklenen: `wine kapalı`. Başka bir bottle'ın wineserver'ı görünüyorsa aynı komut o bottle'ın klasörüyle çalıştırılır.
- Debug Bridge motoru `KOPRU_MOTOR`'dan okuyabilir (Debug paketinde `Resources/Motor` yok; `Engine.locate` sırası: paket → `KOPRU_MOTOR` → geliştirme motoru). Başka motorla açmak için: `open --env KOPRU_MOTOR=<motor> build/Build/Products/Debug/Bridge.app` (Bridge kapalıyken; açıksa `open` yalnız öne getirir).
- Swift: tür ve fonksiyon adları İngilizce, kod açıklamaları ve arayüz metinleri Türkçe. Testler Swift Testing ile: `swift test --package-path KopruCore`.
- Uygulama derlemesi: `xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build build`. Ürün: `build/Build/Products/Debug/Bridge.app`. `Kopru.xcodeproj` yoksa önce `xcodegen generate`.
- Depoda başka bekleyen değişiklikler var (`docs/screenshots/*.png`, `Tools/ekran-goruntusu/main.swift`). Bunlar hiçbir commit'e girmez; her commit'te dosyalar tek tek `git add` edilir.
- Her commit mesajı şu satırla biter:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  ```

## Dosya Haritası

```
Tools/performans-denemeleri/          (yeni) deneme programları
├─ avx.c                              CPUID ve IsProcessorFeaturePresent ile AVX/AVX2 bildirimi
├─ uyku.c                             SetThreadExecutionState çağırıp bekler
├─ derle.sh                           mingw ile cikti/*.exe üretir
└─ calistir.sh                        programı ayrı deneme bottle'ında motorla çalıştırır
Tools/motor-yamalari/
├─ ntdll-game-mode.patch              (yeni, koşullu) yama 7: loader.c, paketli yükleyici bağlantısı
├─ ntdll-uyku-engeli.patch            (yeni) yama 6: system.c, NtSetThreadExecutionState → IOPMAssertion
└─ BENIOKU.md                         yama tablosu ve derleme notu
KopruCore/Sources/KopruCore/
├─ BottleSettings.swift               metalFXUpscale, advertiseAVX alanları
└─ Engine.swift                       iki yeni ortam değişkeni
KopruCore/Tests/KopruCoreTests/
├─ BottleSettingsTests.swift          (yeni) eski JSON ve gidiş-dönüş
└─ EngineTests.swift                  ortam değişkeni testleri
Kopru/Views/BottleSettingsSheet.swift "Performans" bölümü
Kopru/Localizable.xcstrings           derleme yeni metinleri eklerse
README.md                             "Özellikler"e performans maddesi
.gitignore                            Tools/performans-denemeleri/cikti/
docs/superpowers/specs/2026-11-24-oyun-performansi-design.md   Aşama 0 sonucu, durum
```

Motor tarafı (depo dışı): `$W/dlls/ntdll/unix/loader.c`, `$W/dlls/ntdll/unix/system.c`, `$ENG/lib/wine/x86_64-unix/ntdll.so`.

---

### Görev 1: Deneme programları ve temel ölçüm

**Files:**
- Create: `Tools/performans-denemeleri/avx.c`
- Create: `Tools/performans-denemeleri/uyku.c`
- Create: `Tools/performans-denemeleri/derle.sh`
- Create: `Tools/performans-denemeleri/calistir.sh`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `Tools/performans-denemeleri/derle.sh` → `cikti/avx.exe`, `cikti/uyku.exe`. `calistir.sh <exe> [arg…]`: `KOPRU_MOTOR` (varsayılan `$ENG`) ve `WINEPREFIX` (varsayılan `~/WineBottles/kopru-performans`) ortam değişkenlerini okur. `avx.exe` iki satır yazar: `CPUID AVX=<0|1> AVX2=<0|1>` ve `IsProcessorFeaturePresent AVX=<0|1> AVX2=<0|1>`. `uyku.exe <saniye>`: önce `ES_CONTINUOUS|ES_DISPLAY_REQUIRED` ile `<saniye>` bekler, sonra `ES_CONTINUOUS` ile `<saniye>` daha bekler; her adımda bir satır yazar.

- [ ] **Adım 1: `avx.c`'yi yaz**

```c
/* Rosetta'nın AVX bildirimini Wine içinden denetler.
 * Satır 1: işlemcinin CPUID'si (Rosetta ROSETTA_ADVERTISE_AVX=1 ile bildirir).
 * Satır 2: Wine'ın Windows programlarına söylediği (IsProcessorFeaturePresent). */
#include <windows.h>
#include <stdio.h>
#include <cpuid.h>

#ifndef PF_AVX_INSTRUCTIONS_AVAILABLE
#define PF_AVX_INSTRUCTIONS_AVAILABLE 39
#endif
#ifndef PF_AVX2_INSTRUCTIONS_AVAILABLE
#define PF_AVX2_INSTRUCTIONS_AVAILABLE 40
#endif

int main(void)
{
    unsigned a, b, c, d;
    int avx = 0, avx2 = 0;

    if (__get_cpuid(1, &a, &b, &c, &d)) avx = (c >> 28) & 1;
    if (__get_cpuid_count(7, 0, &a, &b, &c, &d)) avx2 = (b >> 5) & 1;
    printf("CPUID AVX=%d AVX2=%d\n", avx, avx2);
    printf("IsProcessorFeaturePresent AVX=%d AVX2=%d\n",
           IsProcessorFeaturePresent(PF_AVX_INSTRUCTIONS_AVAILABLE) ? 1 : 0,
           IsProcessorFeaturePresent(PF_AVX2_INSTRUCTIONS_AVAILABLE) ? 1 : 0);
    return 0;
}
```

- [ ] **Adım 2: `uyku.c`'yi yaz**

```c
/* SetThreadExecutionState'in macOS güç kilidine dönüşmesini denetler.
 * Kullanım: uyku.exe <saniye>. Her adımda `pmset -g assertions` ile bakılır. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    DWORD seconds = argc > 1 ? (DWORD)atoi(argv[1]) : 15;

    printf("1: ES_CONTINUOUS | ES_DISPLAY_REQUIRED\n");
    fflush(stdout);
    SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED);
    Sleep(seconds * 1000);

    printf("2: ES_CONTINUOUS (temizlendi)\n");
    fflush(stdout);
    SetThreadExecutionState(ES_CONTINUOUS);
    Sleep(seconds * 1000);

    printf("3: çıkış\n");
    return 0;
}
```

- [ ] **Adım 3: `derle.sh`'yi yaz**

```zsh
#!/bin/zsh
# Performans denemelerinin Windows programlarını derler. Gerekli: Homebrew mingw-w64 (x86_64-w64-mingw32-gcc).
# Çıktı cikti/ klasörüne yazılır; depoya girmez.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p cikti
for ad in avx uyku; do
  x86_64-w64-mingw32-gcc -O2 -s -o "cikti/$ad.exe" "$ad.c"
  echo "Derlendi: cikti/$ad.exe"
done
```

- [ ] **Adım 4: `calistir.sh`'yi yaz**

```zsh
#!/bin/zsh
# Bir deneme programını ayrı bir deneme bottle'ında, Bridge'in kullandığı motorla çalıştırır.
# Kullanım: ./calistir.sh cikti/avx.exe
#           ROSETTA_ADVERTISE_AVX=1 ./calistir.sh cikti/avx.exe
#           KOPRU_MOTOR=~/WineEngines/baska-motor ./calistir.sh cikti/uyku.exe 15
set -euo pipefail
cd "$(dirname "$0")"
ENG="${KOPRU_MOTOR:-$HOME/WineEngines/WineCX26.3.0-DXMT0.80}"
export WINEPREFIX="${WINEPREFIX:-$HOME/WineBottles/kopru-performans}"
export WINEDEBUG=-all MVK_CONFIG_LOG_LEVEL=0 WINEMSYNC=1 DYLD_FALLBACK_LIBRARY_PATH="$ENG/lib"
if [ ! -d "$WINEPREFIX" ]; then
  echo "Deneme bottle'ı hazırlanıyor: $WINEPREFIX"
  "$ENG/bin/wine" wineboot --init >/dev/null 2>&1
fi
exec "$ENG/bin/wine" "$@"
```

- [ ] **Adım 5: `.gitignore`'a çıktı klasörünü ekle**

`.gitignore`'un sonuna şu satırı ekle:

```
Tools/performans-denemeleri/cikti/
```

- [ ] **Adım 6: Derle ve çalıştırılabilir yap**

```bash
chmod +x Tools/performans-denemeleri/derle.sh Tools/performans-denemeleri/calistir.sh && Tools/performans-denemeleri/derle.sh
```

Beklenen: `Derlendi: cikti/avx.exe` ve `Derlendi: cikti/uyku.exe`.

- [ ] **Adım 7: AVX temel ölçümü (yamasız motor)**

```bash
Tools/performans-denemeleri/calistir.sh cikti/avx.exe
```

```bash
ROSETTA_ADVERTISE_AVX=1 Tools/performans-denemeleri/calistir.sh cikti/avx.exe
```

Beklenen: ilkinde `CPUID AVX=0 AVX2=0`, ikincisinde `CPUID AVX=1 AVX2=1`. Bu sonuç, değişkenin Wine'dan geçip Windows programına ulaştığını gösterir.

Wine'ın `IsProcessorFeaturePresent` satırını iki durum için de not et. CPUID 1 iken bu satır 0 kalabilir; Wine ayrıca işletim sistemi desteğine (XSAVE) bakıyor. Bu durumda spec'in "AVX" bölümüne bir satır eklenir: oyunların çoğu CPUID'ye baktığı için ayar yine işe yarar. Bu satır Görev 7'de spec'le birlikte commit edilir.

- [ ] **Adım 8: Uyku temel ölçümü (yamasız motor: kilit beklenmez)**

```bash
Tools/performans-denemeleri/calistir.sh cikti/uyku.exe 15 & sleep 6; pmset -g assertions | grep -i "SetThreadExecutionState" || echo "KİLİT YOK"; wait
```

Beklenen: `KİLİT YOK`. Yama 6'dan önce başarısız olması gereken deneme budur.

- [ ] **Adım 9: Commit**

```bash
git add .gitignore Tools/performans-denemeleri/avx.c Tools/performans-denemeleri/uyku.c Tools/performans-denemeleri/derle.sh Tools/performans-denemeleri/calistir.sh
git commit -m "Performans denemeleri: AVX ve uyku engeli için Windows programları

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 2: Aşama 0, Game Mode denemesi (karar görevi)

Bu görevin çıktısı bir karar: **A** Wine süreçleri Game Mode'u zaten alıyor (yama 7 gerekmez); **B** paketli bağlantıyla alıyor (Görev 3 yapılır); **C** iki durumda da almıyor (madde düşer). Kullanıcının ekrana bakması gereken adımlar "(kullanıcıyla)" diye işaretli. Görevi yürüten alt ajan bu adımlarda durur ve denetleyiciye (ana oturuma) döner.

**Files:**
- Modify (depo dışı): `$W/dlls/ntdll/unix/loader.c` (yalnız B/C denemesinde; C'de geri alınır)
- Modify: `docs/superpowers/specs/2026-11-24-oyun-performansi-design.md` (3.5'in sonuna "Aşama 0 sonucu")

**Interfaces:**
- Produces: Karar A/B/C. B ise kaynak ağacında `kopru_create_bundle_link()` içeren `loader.c` ve yedeği `loader.c.game-mode-oncesi` (Görev 3 yama dosyasını bunlardan üretir).

- [ ] **Adım 1: Debug Bridge'i derle**

```bash
xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build build 2>&1 | tail -3
```

Beklenen: `** BUILD SUCCEEDED **`.

- [ ] **Adım 2: Game Mode günlüğünü dinlemeye başla**

```bash
log stream --level debug --style compact --predicate 'process == "gamepolicyd" OR subsystem BEGINSWITH "com.apple.gamepolicy"' > "$SCRATCH/gamemode-once.log" 2>&1 &
echo $! > "$SCRATCH/gamemode-log.pid"
```

- [ ] **Adım 3 (kullanıcıyla): Yamasız motorla PEAK'i tam ekranda aç**

Bridge'leri kapat ve Genel Kısıtlar'daki komutla Wine'ın kapalı olduğunu denetle. Debug Bridge'i aç:

```bash
open build/Build/Products/Debug/Bridge.app
```

Kullanıcıdan şunu iste: Steam bottle'ında PEAK'i açsın, tam ekranda ana menüye gelince fareyi ekranın en üstüne götürsün. Menü çubuğunda Game Mode simgesi (oyun kumandası) var mı? İlk açılışta "Game Mode açık" bildirimi de çıkabilir.

PEAK açıkken süreç kaydını al:

```bash
lsappinfo list | grep -B3 -A14 '"PEAK"' | grep -E 'bundleID|executable path|ASN|"PEAK"'
```

Beklenen (bugünkü durum): `bundleID=[ NULL ]`, yürütülebilir dosya `…/winetemp-…/PEAK`.

- [ ] **Adım 4: Günlüğü durdur ve oku**

```bash
kill "$(cat "$SCRATCH/gamemode-log.pid")"; grep -i -E 'PEAK|GameMode|game-mode|session' "$SCRATCH/gamemode-once.log" | head -40
```

Kullanıcı simgeyi gördüyse ya da günlükte PEAK için bir Game Mode oturumu (`GameModeSession`, `game-mode-session`) varsa: **Karar A.** Adım 10'a geç.

- [ ] **Adım 5: Deneme için motorun APFS kopyasını hazırla**

PEAK'i ve Bridge'i kapat, Genel Kısıtlar'daki komutla Wine'ın kapalı olduğunu denetle, sonra:

```bash
cp -c -R ~/WineEngines/WineCX26.3.0-DXMT0.80 ~/WineEngines/deneme-game-mode && echo kopyalandi
```

- [ ] **Adım 6: `loader.c`'ye paketli bağlantıyı ekle**

Önce yedek:

```bash
cp ~/WineBuild/kaynak-26.3.0/sources/wine/dlls/ntdll/unix/loader.c ~/WineBuild/kaynak-26.3.0/sources/wine/dlls/ntdll/unix/loader.c.game-mode-oncesi
```

`$W/dlls/ntdll/unix/loader.c` içinde `kopru_app_name()` fonksiyonunun **hemen arkasına** (kapanış `}`'inden sonra, `replace_wineloader_path_with_link`'ten önce) şunu ekle:

```c
/* Köprü yaması (Game Mode): macOS Game Mode'u tam ekrandaki uygulamanın Info.plist'ine bakarak açar;
 * paketsiz Wine süreçleri bunu alamıyor. Köprü'nün açtığı süreçler (KOPRU_APP_NAME) yükleyicinin
 * bağlantısını winetemp altında küçük bir paketin içinden çalıştırır:
 *   <ad>.app/Contents/MacOS/<ad>       yükleyiciye sabit bağlantı (olmazsa sembolik)
 *   <ad>.app/Contents/MacOS/ntdll.so   yükleyici ntdll.so'yu kendi klasöründe arar (create_tempdir gibi)
 *   <ad>.app/Contents/Info.plist       oyun kategorisi, LSSupportsGameMode, NSHighResolutionCapable,
 *                                      NSMicrophoneUsageDescription (Bridge'in Info.plist'iyle aynı metin)
 * XML'de kaçış gerektiren adlarda paket kurulmaz; düz bağlantıya dönülür. */
static const char kopru_microphone_text[] =
    "Bridge'de çalışan oyunlar ve programlar, sesli sohbet gibi özellikler için mikrofonunuzu kullanmak istiyor.";

static int kopru_write_file( const char *path, const char *data )
{
    size_t len = strlen( data );
    int fd = open( path, O_WRONLY | O_CREAT | O_TRUNC, 0644 );
    int ok;

    if (fd < 0) return 0;
    ok = write( fd, data, len ) == (ssize_t)len;
    close( fd );
    return ok;
}

static char *kopru_create_bundle_link( const char *wineloader_path, const char *app_name )
{
    char *tempdir, *bundle = NULL, *contents = NULL, *macos = NULL, *exe = NULL, *plist_path = NULL;
    char *plist = NULL, *ident = NULL, *ntdll = NULL, *ntdll_link = NULL, *p, *result = NULL;
    struct stat st;

    if (strpbrk( app_name, "&<>\"'" )) return NULL;
    if (!(tempdir = create_tempdir( wineloader_path ))) return NULL;

    if (asprintf( &bundle, "%s%s.app", tempdir, app_name ) < 0) { bundle = NULL; goto done; }
    if (asprintf( &contents, "%s/Contents", bundle ) < 0) { contents = NULL; goto done; }
    if (asprintf( &macos, "%s/MacOS", contents ) < 0) { macos = NULL; goto done; }
    if (asprintf( &exe, "%s/%s", macos, app_name ) < 0) { exe = NULL; goto done; }
    if (strlen( exe ) >= MAX_PATH) goto done;

    /* Bağlantı en son kurulur: varsa paketin geri kalanı da hazırdır. */
    if (!stat( exe, &st )) { result = exe; exe = NULL; goto done; }

    mkdir( bundle, 0700 );
    mkdir( contents, 0700 );
    mkdir( macos, 0700 );

    if (!(ident = strdup( app_name ))) goto done;
    for (p = ident; *p; p++)
        if (!((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') || (*p >= '0' && *p <= '9') || *p == '.'))
            *p = '-';

    if (asprintf( &plist_path, "%s/Info.plist", contents ) < 0) { plist_path = NULL; goto done; }
    if (asprintf( &plist,
                  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                  "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
                  "<plist version=\"1.0\">\n<dict>\n"
                  "\t<key>CFBundleExecutable</key><string>%s</string>\n"
                  "\t<key>CFBundleIdentifier</key><string>dev.kopru.wine.%s</string>\n"
                  "\t<key>CFBundleName</key><string>%s</string>\n"
                  "\t<key>CFBundlePackageType</key><string>APPL</string>\n"
                  "\t<key>LSApplicationCategoryType</key><string>public.app-category.games</string>\n"
                  "\t<key>LSSupportsGameMode</key><true/>\n"
                  "\t<key>NSHighResolutionCapable</key><true/>\n"
                  "\t<key>NSMicrophoneUsageDescription</key><string>%s</string>\n"
                  "</dict>\n</plist>\n",
                  app_name, ident, app_name, kopru_microphone_text ) < 0) { plist = NULL; goto done; }
    if (!kopru_write_file( plist_path, plist )) goto done;

    if (!(ntdll = malloc( strlen( wineloader_path ) + sizeof("/ntdll.so") ))) goto done;
    strcpy( ntdll, wineloader_path );
    if ((p = strrchr( ntdll, '/' ))) *p = 0;
    strcat( ntdll, "/ntdll.so" );
    if (asprintf( &ntdll_link, "%s/ntdll.so", macos ) < 0) { ntdll_link = NULL; goto done; }
    symlink( ntdll, ntdll_link );

    if (!link( wineloader_path, exe ) || !symlink( wineloader_path, exe )) { result = exe; exe = NULL; }

done:
    free( tempdir ); free( bundle ); free( contents ); free( macos ); free( exe );
    free( plist_path ); free( plist ); free( ident ); free( ntdll ); free( ntdll_link );
    return result;
}
```

Aynı dosyada `replace_wineloader_path_with_link`'in başını şöyle değiştir (yalnız ilk satırlar; geri kalanı aynı kalır):

```c
static void replace_wineloader_path_with_link(char **wineloader_path, const char *image_path)
{
    char *app_name = kopru_app_name(); /* Köprü yaması */
    int from_kopru = app_name != NULL; /* Köprü yaması: Game Mode */
    if (!app_name) app_name = extract_exe_name(image_path);
    if (app_name)
    {
        char *preloader_path = from_kopru ? kopru_create_bundle_link(*wineloader_path, app_name) : NULL; /* Köprü yaması: Game Mode */
        if (!preloader_path) preloader_path = create_preloader_link(*wineloader_path, app_name);
        if (preloader_path)
        {
            free(*wineloader_path);
            *wineloader_path = preloader_path;
        }
```

- [ ] **Adım 7: Derle ve yalnız kopyaya koy**

```bash
cd ~/WineBuild/yapi-26.3.0 && arch -x86_64 /bin/zsh -c 'export PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/opt/flex/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"; make dlls/ntdll/ntdll.so' 2>&1 | grep -E 'error|warning: .*loader.c' ; cp dlls/ntdll/ntdll.so ~/WineEngines/deneme-game-mode/lib/wine/x86_64-unix/ntdll.so.yeni && mv ~/WineEngines/deneme-game-mode/lib/wine/x86_64-unix/ntdll.so.yeni ~/WineEngines/deneme-game-mode/lib/wine/x86_64-unix/ntdll.so && echo kuruldu
```

Beklenen: hata satırı yok, `kuruldu`. Geliştirme motoru (`$ENG`) değişmedi.

- [ ] **Adım 8 (kullanıcıyla): Kopya motorla aynı denemeyi yap**

```bash
log stream --level debug --style compact --predicate 'process == "gamepolicyd" OR subsystem BEGINSWITH "com.apple.gamepolicy"' > "$SCRATCH/gamemode-paket.log" 2>&1 &
echo $! > "$SCRATCH/gamemode-log.pid"
open --env KOPRU_MOTOR="$HOME/WineEngines/deneme-game-mode" build/Build/Products/Debug/Bridge.app
```

Kullanıcıdan isteneceklerle süreç kaydı Adım 3'teki gibi. Bu kez beklenen: `bundleID="dev.kopru.wine.PEAK"`, yürütülebilir dosya `…/winetemp-…/PEAK.app/Contents/MacOS/PEAK`.

Kullanıcıdan ayrıca şunları denetlemesini iste:
- Dock'ta PEAK'in adı ve simgesi aynı mı, Dock'taki simge sayısı önceki denemeyle aynı mı?
- Steam'in kendi penceresi açılıyor mu?
- PEAK ana menüye takılmadan geliyor mu? (Mikrofon izni hâlâ Bridge'e bağlı mı; `13312c8`'deki donma geri gelmemeli.)

Sonra günlüğü oku:

```bash
kill "$(cat "$SCRATCH/gamemode-log.pid")"; grep -i -E 'PEAK|GameMode|game-mode|session' "$SCRATCH/gamemode-paket.log" | head -40
```

Kullanıcı simgeyi gördüyse ya da günlükte oturum varsa ve üç denetim de sorunsuzsa: **Karar B.** Bunlardan biri sorunluysa ya da Game Mode yine açılmıyorsa: **Karar C.**

- [ ] **Adım 9: Karar C ise kaynak ağacını geri al**

Yalnız Karar C'de:

```bash
mv ~/WineBuild/kaynak-26.3.0/sources/wine/dlls/ntdll/unix/loader.c.game-mode-oncesi ~/WineBuild/kaynak-26.3.0/sources/wine/dlls/ntdll/unix/loader.c && echo geri-alindi
```

Karar ne olursa olsun, Bridge ve PEAK kapandıktan sonra deneme kopyasını sil (Adım 5 yapılmadıysa, yani Karar A'da, silinecek kopya yoktur):

```bash
WINEPREFIX="$HOME/Library/Application Support/Kopru/Bottles/Steam" ~/WineEngines/deneme-game-mode/bin/wineserver -k 2>/dev/null; sleep 2; rm -rf ~/WineEngines/deneme-game-mode && echo silindi
```

- [ ] **Adım 10: Sonucu spec'e yaz**

`docs/superpowers/specs/2026-11-24-oyun-performansi-design.md` içinde 3.5'in son maddesinden ("Steam'in kendisi de …") sonra, `## 4. Test`'ten önce şu alt başlığı ekle. Köşeli parantezleri gözlenen gerçek değerlerle doldur:

```markdown
**Aşama 0 sonucu (2026-11-24): Karar [A|B|C].**

- Yamasız motor: `lsappinfo` bundleID [değer]; Game Mode simgesi [görüldü|görülmedi]; günlükte [ilgili satır ya da "PEAK için oturum yok"].
- Paketli bağlantı (yalnız B/C): bundleID [değer]; Game Mode [açıldı|açılmadı]; Dock [aynı|farklı: …]; Steam penceresi [açıldı|…]; PEAK ana menü [geldi|dondu].
- Sonuç: [A: yama 7 gerekmiyor | B: yama 7 uygulanıyor (Görev 3) | C: madde düştü, neden: …].
```

- [ ] **Adım 11: Commit**

```bash
git add docs/superpowers/specs/2026-11-24-oyun-performansi-design.md
git commit -m "Spec: Game Mode denemesinin (Aşama 0) sonucu

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 3: Motor yaması 7, Game Mode (yalnız Karar B)

Karar A ya da C ise bu görev atlanır; plan Görev 4'ten sürer.

**Files:**
- Create: `Tools/motor-yamalari/ntdll-game-mode.patch`
- Modify: `Tools/motor-yamalari/BENIOKU.md` (tablo)
- Modify (depo dışı): `$ENG/lib/wine/x86_64-unix/ntdll.so`

**Interfaces:**
- Consumes: Görev 2'nin `loader.c` (değişmiş) ve `loader.c.game-mode-oncesi` (yedek) dosyaları.
- Produces: Geliştirme motorunda paketli bağlantı. `KOPRU_APP_NAME` olan her süreç `…/winetemp-…/<ad>.app/Contents/MacOS/<ad>`'dan çalışır.

- [ ] **Adım 1: Yama dosyasını üret**

```bash
cd ~/WineBuild/kaynak-26.3.0/sources/wine && {
printf '%s\n' \
"Köprü yaması (Game Mode): Köprü'nün açtığı süreçler (KOPRU_APP_NAME) yükleyicinin bağlantısını winetemp altında küçük bir" \
"<ad>.app paketinin içinden çalıştırır. Info.plist oyun kategorisi ve LSSupportsGameMode taşır; macOS tam ekranda Game Mode'u açar." \
"NSHighResolutionCapable ve NSMicrophoneUsageDescription bugünkü davranışı korur. ntdll-dock-adi.patch'ten sonra uygulanır: patch -p1 < ntdll-game-mode.patch" \
""
diff -u --label a/dlls/ntdll/unix/loader.c --label b/dlls/ntdll/unix/loader.c dlls/ntdll/unix/loader.c.game-mode-oncesi dlls/ntdll/unix/loader.c
} > /Users/umuttorun/Desktop/Apps/Kopru/Tools/motor-yamalari/ntdll-game-mode.patch; echo "satır: $(wc -l < /Users/umuttorun/Desktop/Apps/Kopru/Tools/motor-yamalari/ntdll-game-mode.patch)"
```

Beklenen: 100 satırın üzerinde bir yama; içinde `kopru_create_bundle_link` ve `from_kopru` var.

- [ ] **Adım 2: Yamanın temiz uygulandığını doğrula**

```bash
cd ~/WineBuild/kaynak-26.3.0/sources/wine && cp dlls/ntdll/unix/loader.c "$SCRATCH/loader.c.yamali" && cp dlls/ntdll/unix/loader.c.game-mode-oncesi dlls/ntdll/unix/loader.c && patch -p1 --dry-run < /Users/umuttorun/Desktop/Apps/Kopru/Tools/motor-yamalari/ntdll-game-mode.patch && cp "$SCRATCH/loader.c.yamali" dlls/ntdll/unix/loader.c && echo temiz
```

Beklenen: `checking file dlls/ntdll/unix/loader.c` ve `temiz`.

- [ ] **Adım 3: Geliştirme motoruna kur**

Bridge kapalı ve hiçbir Wine süreci açık değilken:

```bash
E=~/WineEngines/WineCX26.3.0-DXMT0.80/lib/wine/x86_64-unix; cp "$E/ntdll.so" ~/WineBuild/yedek/ntdll.so.game-mode-oncesi && cp ~/WineBuild/yapi-26.3.0/dlls/ntdll/ntdll.so "$E/ntdll.so.yeni" && mv "$E/ntdll.so.yeni" "$E/ntdll.so" && echo kuruldu
```

(`yapi-26.3.0`'daki `ntdll.so` Görev 2 Adım 7'de bu kaynakla derlendi.)

- [ ] **Adım 4 (kullanıcıyla): Geliştirme motoruyla doğrula**

```bash
open build/Build/Products/Debug/Bridge.app
```

Kullanıcı PEAK'i tam ekranda açar ve Game Mode simgesini görür. `lsappinfo` satırı Görev 2 Adım 8'deki gibi `dev.kopru.wine.PEAK` gösterir.

- [ ] **Adım 5: BENIOKU tablosuna satır ekle**

`Tools/motor-yamalari/BENIOKU.md` tablosunun son satırından (`| 5 | wineserver-klasor-bildirimi.patch | …`) sonra şu satırı ekle:

```markdown
| 7 | `ntdll-game-mode.patch` | Köprü'nün açtığı süreçler (`KOPRU_APP_NAME`) yükleyicinin bağlantısını `winetemp-…/<ad>.app` paketinin içinden çalıştırır. Info.plist oyun kategorisi ve `LSSupportsGameMode` taşıdığı için macOS tam ekranda Game Mode'u açar. `NSHighResolutionCapable` ve `NSMicrophoneUsageDescription` bugünkü davranışı korur. `ntdll-dock-adi.patch`'ten sonra uygulanır. | `Engine.appNameVariable` (`KOPRU_APP_NAME`) |
```

- [ ] **Adım 6: Commit**

```bash
git add Tools/motor-yamalari/ntdll-game-mode.patch Tools/motor-yamalari/BENIOKU.md
git commit -m "Motor yaması: Game Mode (Wine süreçleri paket içinden çalışır)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 4: Motor yaması 6, uyku engeli

**Files:**
- Create: `Tools/motor-yamalari/ntdll-uyku-engeli.patch`
- Modify: `Tools/motor-yamalari/BENIOKU.md` (tablo ve derleme notu)
- Modify (depo dışı): `$W/dlls/ntdll/unix/system.c`, `$ENG/lib/wine/x86_64-unix/ntdll.so`

**Interfaces:**
- Consumes: Görev 1'in `uyku.exe` ve `calistir.sh` dosyaları.
- Produces: Geliştirme motorunda `SetThreadExecutionState` → `pmset -g assertions`'ta `"Wine: SetThreadExecutionState"` adlı kilit.

- [ ] **Adım 1: Başarısız denemeyi yeniden çalıştır**

```bash
Tools/performans-denemeleri/calistir.sh cikti/uyku.exe 15 & sleep 6; pmset -g assertions | grep -i "SetThreadExecutionState" || echo "KİLİT YOK"; wait
```

Beklenen: `KİLİT YOK`.

- [ ] **Adım 2: `system.c`'nin yedeğini al**

```bash
cp ~/WineBuild/kaynak-26.3.0/sources/wine/dlls/ntdll/unix/system.c ~/WineBuild/kaynak-26.3.0/sources/wine/dlls/ntdll/unix/system.c.uyku-oncesi
```

- [ ] **Adım 3: IOPMLib başlığını ekle**

`$W/dlls/ntdll/unix/system.c` içinde `#ifdef __APPLE__` bloğundaki şu satırın:

```c
# include <IOKit/ps/IOPowerSources.h>
```

hemen altına ekle:

```c
# include <IOKit/pwr_mgt/IOPMLib.h> /* Köprü yaması: uyku engeli */
```

- [ ] **Adım 4: `NtSetThreadExecutionState`'i güç kilitlerine bağla**

Aynı dosyada şu bloğu:

```c
/******************************************************************************
 *              NtSetThreadExecutionState  (NTDLL.@)
 */
NTSTATUS WINAPI NtSetThreadExecutionState( EXECUTION_STATE new_state, EXECUTION_STATE *old_state )
{
    static EXECUTION_STATE current = ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED | ES_USER_PRESENT;

    WARN( "(0x%x, %p): stub, harmless.\n", new_state, old_state );
    *old_state = current;
    if (!(current & ES_CONTINUOUS) || (new_state & ES_CONTINUOUS)) current = new_state;
    return STATUS_SUCCESS;
}
```

şununla değiştir:

```c
#ifdef __APPLE__
/* Köprü yaması (uyku engeli): SetThreadExecutionState macOS'un güç kilitlerine bağlanır.
 * ES_CONTINUOUS ile istenen durum süreç genelinde tutulur (Windows iş parçacığı başına tutar; oyunlarda
 * çağrı neredeyse hep tek iş parçacığından gelir). Süreç kapanınca macOS kilitleri kendisi bırakır.
 * Tek seferlik ES_DISPLAY_REQUIRED boşta kalma sayacını sıfırlar; tek seferlik ES_SYSTEM_REQUIRED yok
 * sayılır, çünkü kullanıcı etkinliği bildirmek ekranı da uyandırır. */
#ifndef ES_AWAYMODE_REQUIRED
#define ES_AWAYMODE_REQUIRED 0x00000040
#endif

static pthread_mutex_t kopru_power_mutex = PTHREAD_MUTEX_INITIALIZER;
static IOPMAssertionID kopru_display_assertion = kIOPMNullAssertionID;
static IOPMAssertionID kopru_system_assertion = kIOPMNullAssertionID;
static IOPMAssertionID kopru_activity_assertion = kIOPMNullAssertionID;

static void kopru_set_assertion( IOPMAssertionID *id, CFStringRef type, int wanted )
{
    if (wanted && *id == kIOPMNullAssertionID)
    {
        if (IOPMAssertionCreateWithName( type, kIOPMAssertionLevelOn,
                                         CFSTR("Wine: SetThreadExecutionState"), id ) != kIOReturnSuccess)
            *id = kIOPMNullAssertionID;
    }
    else if (!wanted && *id != kIOPMNullAssertionID)
    {
        IOPMAssertionRelease( *id );
        *id = kIOPMNullAssertionID;
    }
}

static void kopru_apply_execution_state( EXECUTION_STATE state )
{
    pthread_mutex_lock( &kopru_power_mutex );
    if (state & ES_CONTINUOUS)
    {
        kopru_set_assertion( &kopru_display_assertion, kIOPMAssertionTypePreventUserIdleDisplaySleep,
                             (state & ES_DISPLAY_REQUIRED) != 0 );
        kopru_set_assertion( &kopru_system_assertion, kIOPMAssertionTypePreventUserIdleSystemSleep,
                             (state & (ES_SYSTEM_REQUIRED | ES_AWAYMODE_REQUIRED)) != 0 );
    }
    else if (state & ES_DISPLAY_REQUIRED)
    {
        IOPMAssertionDeclareUserActivity( CFSTR("Wine: SetThreadExecutionState"), kIOPMUserActiveLocal,
                                          &kopru_activity_assertion );
    }
    pthread_mutex_unlock( &kopru_power_mutex );
}
#endif

/******************************************************************************
 *              NtSetThreadExecutionState  (NTDLL.@)
 */
NTSTATUS WINAPI NtSetThreadExecutionState( EXECUTION_STATE new_state, EXECUTION_STATE *old_state )
{
    static EXECUTION_STATE current = ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED | ES_USER_PRESENT;

    TRACE( "(0x%x, %p)\n", new_state, old_state );
    *old_state = current;
    if (!(current & ES_CONTINUOUS) || (new_state & ES_CONTINUOUS)) current = new_state;
#ifdef __APPLE__
    kopru_apply_execution_state( new_state ); /* Köprü yaması */
#endif
    return STATUS_SUCCESS;
}
```

- [ ] **Adım 5: Derle**

```bash
cd ~/WineBuild/yapi-26.3.0 && arch -x86_64 /bin/zsh -c 'export PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/opt/flex/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"; make dlls/ntdll/ntdll.so' 2>&1 | grep -E 'error|warning: .*system.c' ; ls -la dlls/ntdll/ntdll.so
```

Beklenen: hata satırı yok; `ntdll.so`'nun zamanı şimdi.

- [ ] **Adım 6: Geliştirme motoruna kur**

Bridge kapalı ve hiçbir Wine süreci açık değilken:

```bash
E=~/WineEngines/WineCX26.3.0-DXMT0.80/lib/wine/x86_64-unix; cp "$E/ntdll.so" ~/WineBuild/yedek/ntdll.so.uyku-engeli-oncesi && cp ~/WineBuild/yapi-26.3.0/dlls/ntdll/ntdll.so "$E/ntdll.so.yeni" && mv "$E/ntdll.so.yeni" "$E/ntdll.so" && echo kuruldu
```

- [ ] **Adım 7: Denemenin geçtiğini doğrula**

```bash
Tools/performans-denemeleri/calistir.sh cikti/uyku.exe 15 & sleep 6; echo "--- 1. adımda:"; pmset -g assertions | grep -i "SetThreadExecutionState"; sleep 15; echo "--- 2. adımda:"; pmset -g assertions | grep -i "SetThreadExecutionState" || echo "KİLİT YOK"; wait; echo "--- çıkıştan sonra:"; pmset -g assertions | grep -i "SetThreadExecutionState" || echo "KİLİT YOK"
```

Beklenen:
- 1. adımda `PreventUserIdleDisplaySleep named: "Wine: SetThreadExecutionState"` içeren bir satır.
- 2. adımda ve çıkıştan sonra `KİLİT YOK`.

- [ ] **Adım 8: Yama dosyasını üret ve temiz uygulandığını doğrula**

```bash
cd ~/WineBuild/kaynak-26.3.0/sources/wine && {
printf '%s\n' \
"Köprü yaması (uyku engeli): SetThreadExecutionState macOS'un güç kilitlerine (IOPMAssertion) bağlanır." \
"ES_CONTINUOUS|ES_DISPLAY_REQUIRED isteyen program açıkken ekran kararmaz; ES_SYSTEM_REQUIRED Mac'in uyumasını engeller." \
"Wine'da bu çağrı taslaktı; kumandayla oynanan oyunlarda ekran kararıyordu." \
"ntdll-saat-dilimi.patch'ten sonra uygulanır: patch -p1 < ntdll-uyku-engeli.patch" \
""
diff -u --label a/dlls/ntdll/unix/system.c --label b/dlls/ntdll/unix/system.c dlls/ntdll/unix/system.c.uyku-oncesi dlls/ntdll/unix/system.c
} > /Users/umuttorun/Desktop/Apps/Kopru/Tools/motor-yamalari/ntdll-uyku-engeli.patch
cp dlls/ntdll/unix/system.c "$SCRATCH/system.c.yamali" && cp dlls/ntdll/unix/system.c.uyku-oncesi dlls/ntdll/unix/system.c && patch -p1 --dry-run < /Users/umuttorun/Desktop/Apps/Kopru/Tools/motor-yamalari/ntdll-uyku-engeli.patch && cp "$SCRATCH/system.c.yamali" dlls/ntdll/unix/system.c && echo temiz
```

Beklenen: `checking file dlls/ntdll/unix/system.c` ve `temiz`.

- [ ] **Adım 9: BENIOKU'yu güncelle**

`Tools/motor-yamalari/BENIOKU.md` tablosunda `| 5 | …` satırının hemen arkasına (Görev 3 yapıldıysa 7. satırdan önce) şu satırı ekle:

```markdown
| 6 | `ntdll-uyku-engeli.patch` | `SetThreadExecutionState` macOS'un güç kilitlerine bağlanır: `ES_CONTINUOUS\|ES_DISPLAY_REQUIRED` isteyen program açıkken ekran kararmaz, `ES_SYSTEM_REQUIRED` Mac'in uyumasını engeller (`pmset -g assertions`'ta "Wine: SetThreadExecutionState"). Wine'da taslaktı; kumandayla oynanan oyunlarda ekran kararıyordu. `ntdll-saat-dilimi.patch`'ten sonra uygulanır. Deneme: `Tools/performans-denemeleri/uyku.c`. | Yok |
```

Tablonun altındaki paragrafta şu cümle başını:

```
İlk üçü yalnız `dlls/ntdll/unix/` dosyalarına dokunur;
```

şununla değiştir:

```
`ntdll-` ile başlayan yamalar yalnız `dlls/ntdll/unix/` dosyalarına dokunur;
```

- [ ] **Adım 10: Commit**

```bash
git add Tools/motor-yamalari/ntdll-uyku-engeli.patch Tools/motor-yamalari/BENIOKU.md
git commit -m "Motor yaması: oyun istediğinde ekran kararmaz (SetThreadExecutionState)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 5: KopruCore, MetalFX ve AVX ayarları

**Files:**
- Modify: `KopruCore/Sources/KopruCore/BottleSettings.swift`
- Modify: `KopruCore/Sources/KopruCore/Engine.swift`
- Create: `KopruCore/Tests/KopruCoreTests/BottleSettingsTests.swift`
- Modify: `KopruCore/Tests/KopruCoreTests/EngineTests.swift`

**Interfaces:**
- Produces:
  - `BottleSettings.metalFXUpscale: Bool?`, `BottleSettings.advertiseAVX: Bool?` (`nil` = kapalı).
  - `BottleSettings.init(msync: Bool = true, fpsHud: Bool = false, wined3dPrograms: [String]? = nil, metalFXUpscale: Bool? = nil, advertiseAVX: Bool? = nil)`.
  - `Engine.metalFXVariable == "DXMT_METALFX_SPATIAL_SWAPCHAIN"`, `Engine.advertiseAVXVariable == "ROSETTA_ADVERTISE_AVX"`.

- [ ] **Adım 1: Başarısız testleri yaz**

`KopruCore/Tests/KopruCoreTests/BottleSettingsTests.swift`:

```swift
import Foundation
import Testing
@testable import KopruCore

struct BottleSettingsTests {
    @Test func oldKopruJSONDecodesWithoutPerformanceFields() throws {
        // Bu Mac'teki Steam bottle'ının kopru.json'undaki ayarlar; virtualDesktop artık yok sayılıyor.
        let json = #"{"fpsHud":false,"msync":true,"virtualDesktop":{"mode":"auto"}}"#
        let settings = try JSONDecoder().decode(BottleSettings.self, from: Data(json.utf8))
        #expect(settings == BottleSettings(msync: true, fpsHud: false))
        #expect(settings.metalFXUpscale == nil)
        #expect(settings.advertiseAVX == nil)
    }

    @Test func performanceFieldsRoundTrip() throws {
        let settings = BottleSettings(metalFXUpscale: true, advertiseAVX: false)
        let decoded = try JSONDecoder().decode(BottleSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
        #expect(decoded.metalFXUpscale == true)
        #expect(decoded.advertiseAVX == false)
    }
}
```

`KopruCore/Tests/KopruCoreTests/EngineTests.swift` içinde `noWined3dProgramsClearsEngineVariable` testinden sonra, struct'ın kapanışından önce ekle:

```swift
    @Test func metalFXAndAVXBecomeVariables() {
        let engine = Engine(root: URL(fileURLWithPath: "/Motor", isDirectory: true))
        let env = engine.environment(prefix: URL(fileURLWithPath: "/B"),
                                     settings: BottleSettings(metalFXUpscale: true, advertiseAVX: true),
                                     base: [:])
        #expect(Engine.metalFXVariable == "DXMT_METALFX_SPATIAL_SWAPCHAIN")
        #expect(Engine.advertiseAVXVariable == "ROSETTA_ADVERTISE_AVX")
        #expect(env[Engine.metalFXVariable] == "1")
        #expect(env[Engine.advertiseAVXVariable] == "1")
    }

    @Test func metalFXAndAVXOffClearVariables() {
        let engine = Engine(root: URL(fileURLWithPath: "/Motor", isDirectory: true))
        // Bridge'in kendi ortamında olsalar bile kapalı ayar Wine'a geçirmez.
        let base = [Engine.metalFXVariable: "1", Engine.advertiseAVXVariable: "1"]
        for settings in [BottleSettings(), BottleSettings(metalFXUpscale: false, advertiseAVX: false)] {
            let env = engine.environment(prefix: URL(fileURLWithPath: "/B"), settings: settings, base: base)
            #expect(env[Engine.metalFXVariable] == nil)
            #expect(env[Engine.advertiseAVXVariable] == nil)
        }
    }
```

- [ ] **Adım 2: Testlerin başarısız olduğunu gör**

```bash
swift test --package-path KopruCore --filter "BottleSettingsTests|EngineTests" 2>&1 | tail -15
```

Beklenen: derleme hatası; `extra arguments at positions …` ya da `has no member 'metalFXVariable'`.

- [ ] **Adım 3: `BottleSettings`'e alanları ekle**

`KopruCore/Sources/KopruCore/BottleSettings.swift` içinde `public var wined3dPrograms: [String]?` satırından sonra ve `init`'i değiştirerek dosyanın struct gövdesi şöyle olur:

```swift
public struct BottleSettings: Codable, Hashable, Sendable {
    /// WINEMSYNC: Mach semaforlarıyla senkronizasyon; oyunlarda wineserver yükünü azaltır.
    /// Aynı bottle'daki bütün süreçler aynı değerle başlamalı.
    public var msync: Bool
    /// Metal HUD (kare hızı göstergesi).
    public var fpsHud: Bool
    /// DXMT yerine Wine'ın kendi Direct3D'siyle (wined3d) açılacak programların exe adları (ör. "Launcher.exe").
    /// Bottle'daki öteki programlar DXMT'de kalır. Motor bunu `Engine.wined3dProgramsVariable` ile alır;
    /// wined3d'nin OpenGL kullanması için tarif ayrıca `AppDefaults\<exe>\Direct3D\renderer=gl` yazar.
    /// Eski kopru.json dosyalarında yoktur.
    public var wined3dPrograms: [String]?
    /// DXMT'nin MetalFX uzamsal ölçekleyicisi (2×): oyun aynı çözünürlükte çizer, çıktı Retina'ya büyütülür.
    /// Yalnız DXMT'den geçen programlar (D3D10/11). Motor bunu `Engine.metalFXVariable` ile alır.
    /// Eski kopru.json dosyalarında yoktur; nil = kapalı.
    public var metalFXUpscale: Bool?
    /// Rosetta'nın AVX/AVX2'yi programlara bildirmesi (`Engine.advertiseAVXVariable`). nil = kapalı.
    public var advertiseAVX: Bool?

    public init(msync: Bool = true, fpsHud: Bool = false, wined3dPrograms: [String]? = nil,
                metalFXUpscale: Bool? = nil, advertiseAVX: Bool? = nil) {
        self.msync = msync
        self.fpsHud = fpsHud
        self.wined3dPrograms = wined3dPrograms
        self.metalFXUpscale = metalFXUpscale
        self.advertiseAVX = advertiseAVX
    }

    public static let `default` = BottleSettings()
}
```

- [ ] **Adım 4: `Engine`'e değişkenleri ekle**

`KopruCore/Sources/KopruCore/Engine.swift` içinde `wined3dProgramsVariable` tanımının arkasına ekle:

```swift
    /// DXMT bu değişken "1" iken swapchain'i MetalFX uzamsal ölçekleyiciyle kurar (ölçek varsayılanı 2×,
    /// `d3d11.metalSpatialUpscaleFactor`). Aygıt desteklemiyorsa DXMT normal swapchain'e döner.
    public static let metalFXVariable = "DXMT_METALFX_SPATIAL_SWAPCHAIN"

    /// Rosetta bu değişken "1" iken AVX ve AVX2'yi CPUID'de bildirir (varsayılan: bildirmez).
    public static let advertiseAVXVariable = "ROSETTA_ADVERTISE_AVX"
```

Aynı dosyada `environment(prefix:settings:base:)` içinde `env[Self.wined3dProgramsVariable] = …` satırından sonra, `return env`'den önce ekle:

```swift
        env[Self.metalFXVariable] = settings.metalFXUpscale == true ? "1" : nil
        env[Self.advertiseAVXVariable] = settings.advertiseAVX == true ? "1" : nil
```

- [ ] **Adım 5: Testlerin geçtiğini gör**

```bash
swift test --package-path KopruCore --filter "BottleSettingsTests|EngineTests" 2>&1 | tail -5
```

Beklenen: `Test run with … tests passed`.

- [ ] **Adım 6: Bütün paket testleri**

```bash
swift test --package-path KopruCore 2>&1 | tail -5
```

Beklenen: bütün testler geçer. `PlatformTrialTests` `KOPRU_TARIF_DENE` olmadan atlanır.

- [ ] **Adım 7: Commit**

```bash
git add KopruCore/Sources/KopruCore/BottleSettings.swift KopruCore/Sources/KopruCore/Engine.swift KopruCore/Tests/KopruCoreTests/BottleSettingsTests.swift KopruCore/Tests/KopruCoreTests/EngineTests.swift
git commit -m "KopruCore: bottle başına MetalFX ve AVX ayarı

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 6: Bottle Ayarları penceresinde "Performans" bölümü

**Files:**
- Modify: `Kopru/Views/BottleSettingsSheet.swift`
- Modify: `Kopru/Localizable.xcstrings` (yalnız derleme değiştirirse)

**Interfaces:**
- Consumes: `BottleSettings.metalFXUpscale`, `BottleSettings.advertiseAVX` (Görev 5).
- Produces: Kaydedince `kopru.json`'da `"metalFXUpscale"` ve `"advertiseAVX"` alanları (`true`/`false`).

- [ ] **Adım 1: Pencereyi güncelle**

`Kopru/Views/BottleSettingsSheet.swift`'in tamamı:

```swift
import AppKit
import KopruCore
import SwiftUI

struct BottleSettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let bottle: Bottle
    @State private var name: String
    @State private var msync: Bool
    @State private var fpsHud: Bool
    @State private var metalFX: Bool
    @State private var avx: Bool
    @State private var confirmDelete = false

    init(bottle: Bottle) {
        self.bottle = bottle
        let settings = bottle.info.settings
        _name = State(initialValue: bottle.info.name)
        _msync = State(initialValue: settings.msync)
        _fpsHud = State(initialValue: settings.fpsHud)
        _metalFX = State(initialValue: settings.metalFXUpscale ?? false)
        _avx = State(initialValue: settings.advertiseAVX ?? false)
    }

    private var settings: BottleSettings {
        // Pencerede gösterilmeyen ayarlar (ör. tarifin wined3d programları) olduğu gibi kalır.
        var settings = bottle.info.settings
        settings.msync = msync
        settings.fpsHud = fpsHud
        settings.metalFXUpscale = metalFX
        settings.advertiseAVX = avx
        return settings
    }

    /// MetalFX ve AVX ortam değişkeniyle geçer: açık programlar eski değerle sürer, programları kapatmak gerekmez.
    private var performanceChanged: Bool {
        let saved = bottle.info.settings
        return metalFX != (saved.metalFXUpscale ?? false) || avx != (saved.advertiseAVX ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bottle Ayarları").font(.title2.bold())
            Form {
                Section {
                    TextField("Ad", text: $name)
                    Toggle("MSync (oyunlarda daha akıcı)", isOn: $msync)
                    if msync != bottle.info.settings.msync {
                        Text("Kaydedince bottle'daki açık programlar kapatılacak.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Toggle("FPS göstergesi", isOn: $fpsHud)
                }
                Section("Performans") {
                    Toggle(isOn: $metalFX) {
                        Text("Keskin görüntü (MetalFX)")
                        Text("DirectX 11 oyunlarını MetalFX ile Retina çözünürlüğe büyütür. Retina olmayan ekranda kapalı bırakın.")
                    }
                    Toggle(isOn: $avx) {
                        Text("AVX desteği")
                        Text("AVX isteyen oyunlar için. Bazı oyunlar yavaşlayabilir.")
                    }
                    if performanceChanged {
                        Text("Açık programlar yeniden açılınca geçerli olur.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Button("Windows Ayarları") { model.openWineSettings(bottle) }
                Button("C: Sürücüsünü Aç") { NSWorkspace.shared.open(bottle.driveC) }
                Spacer()
                Button("Bottle'ı Sil…", role: .destructive) { confirmDelete = true }
            }
            HStack {
                Spacer()
                Button("Vazgeç", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Kaydet") {
                    model.update(bottle, name: name, settings: settings)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520, height: 600)
        .confirmationDialog("“\(bottle.info.name)” silinsin mi?", isPresented: $confirmDelete) {
            Button("Çöp Kutusu'na Taşı", role: .destructive) {
                model.deleteBottle(bottle)
                dismiss()
            }
        } message: {
            Text("Bottle ve içine kurulan programlar Çöp Kutusu'na taşınır.")
        }
    }
}
```

`AppModel.update` değişmez: yalnız MSync değişince bottle'ı durdurur.

- [ ] **Adım 2: Derle**

```bash
xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build build 2>&1 | grep -E 'error:|BUILD' | tail -5
```

Beklenen: `** BUILD SUCCEEDED **`.

- [ ] **Adım 3 (kullanıcıyla): Pencereyi gör ve kaydet**

```bash
open build/Build/Products/Debug/Bridge.app
```

Kullanıcıdan Steam bottle'ının ayarlarını açmasını iste ve şunları denetlet:
- "Performans" bölümünde iki anahtar ve açıklamaları görünüyor mu?
- Pencere kesilmeden sığıyor mu? Sığmıyorsa `.frame(width: 520, height: 600)` yüksekliği büyütülür ve 2. adım yinelenir.
- Bir anahtarı değiştirince "Açık programlar yeniden açılınca geçerli olur." çıkıyor mu?

Sonra kullanıcı iki anahtarı da açıp Kaydet'e bassın:

```bash
grep -E 'metalFXUpscale|advertiseAVX' ~/Library/Application\ Support/Kopru/Bottles/Steam/kopru.json
```

Beklenen: `"advertiseAVX" : true` ve `"metalFXUpscale" : true`.

- [ ] **Adım 4: Ortamın Wine'a geçtiğini doğrula**

Kullanıcı Steam'i Bridge'den açsın, sonra:

```bash
ps eww -p "$(pgrep -f 'steam.exe' | head -1)" | tr ' ' '\n' | grep -E '^(DXMT_METALFX_SPATIAL_SWAPCHAIN|ROSETTA_ADVERTISE_AVX)='
```

Beklenen: `DXMT_METALFX_SPATIAL_SWAPCHAIN=1` ve `ROSETTA_ADVERTISE_AVX=1`. (`ps` ortamı göstermezse günlük yeterli değildir; bu durumda Görev 7'deki HUD denetimi kanıt sayılır.)

- [ ] **Adım 5: Metin kataloğunu denetle ve commit et**

```bash
git status --short Kopru/
```

`Kopru/Localizable.xcstrings` değiştiyse o da commit'e girer:

```bash
git add Kopru/Views/BottleSettingsSheet.swift
git add Kopru/Localizable.xcstrings 2>/dev/null; git commit -m "Bottle Ayarları: Performans bölümü (MetalFX, AVX)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Görev 7: Uçtan uca deneme, gerileme ve belgeler

**Files:**
- Modify: `README.md` ("Özellikler")
- Modify: `docs/superpowers/specs/2026-11-24-oyun-performansi-design.md` ("Durum" satırı; Görev 1 Adım 7'nin AVX notu)

**Interfaces:**
- Consumes: Görev 3 (yapıldıysa), Görev 4, 5 ve 6'nın çıktıları; geliştirme motoru ikisini de içeriyor.

- [ ] **Adım 1 (kullanıcıyla): MetalFX'i oyunda gör**

Steam bottle'ında "FPS göstergesi" ve "Keskin görüntü (MetalFX)" açıkken kullanıcı PEAK'i açsın. Oyun ana menüdeyken:

```bash
screencapture -x "$SCRATCH/metalfx-acik.png"
```

Görüntüyü oku. Metal HUD'da `MetalFX: Spatial` ve `Scale: AxB->CxD` satırları olmalı; C = 2×A, D = 2×B.

Sonra MetalFX'i kapat, PEAK'i yeniden aç ve aynı görüntüyü al (`metalfx-kapali.png`). Bu kez `MetalFX` satırı yok. İki görüntüdeki netlik farkını kullanıcıya göster. FPS değerlerini (HUD) iki durum için not et.

- [ ] **Adım 2 (kullanıcıyla): Uyku engelini gerçek oyunda dene**

PEAK açıkken:

```bash
pmset -g assertions | grep -i -E 'SetThreadExecutionState|screen saver' || echo "KİLİT YOK"
```

Sonucu not et. PEAK (Unity) bu çağrıyı yapmıyorsa `KİLİT YOK` normaldir; spec'teki "Unity'nin bu çağrıyı yapıp yapmadığı not edilir" maddesi için kaydedilir.

- [ ] **Adım 3 (kullanıcıyla): Gerileme**

Kullanıcıyla sırayla:
- Steam açılıyor, giriş ve mağaza çiziliyor (MetalFX açıkken de).
- Epic Games Launcher açılıyor.
- Rockstar Games Launcher açılıyor; Dock'ta tek simge var.
- PEAK ana menüye donmadan geliyor (mikrofon).
- Wine süreçlerinin Dock'taki adları değişmemiş.
- Görev 3 yapıldıysa PEAK tam ekrandayken Game Mode simgesi görünüyor.

Bir madde bozuksa o maddenin görevine dönülür ve neden spec'e yazılır.

- [ ] **Adım 4: Deneme ayarlarını geri al**

Steam bottle'ı kullanıcının kendi bottle'ı. Kullanıcı açık kalmasını istemiyorsa MetalFX, AVX ve FPS göstergesini Bottle Ayarları'ndan eski hâline (kapalı) getirsin.

- [ ] **Adım 5: README "Özellikler"e madde ekle**

`README.md`'de `- **Motor uygulamanın içinde:** …` maddesinin arkasına şu maddeyi ekle. Görev 3 yapılmadıysa son cümleyi ("Tam ekrandaki …") çıkar:

```markdown
- **Oyun performansı:** Bottle ayarlarından DirectX 11 oyunlarını MetalFX ile Retina çözünürlüğe büyütebilir, AVX isteyen oyunlar için Rosetta'nın AVX desteğini açabilirsiniz. Oyun ekranın açık kalmasını istediğinde Mac uykuya geçmez. Tam ekrandaki oyunlarda macOS Game Mode devreye girer.
```

- [ ] **Adım 6: Spec'in durumunu güncelle**

`docs/superpowers/specs/2026-11-24-oyun-performansi-design.md`'nin ikinci satırını:

```markdown
- **Durum:** Umut tasarımı onayladı (2026-11-24); uygulanmadı.
```

şununla değiştir (köşeli parantezi Aşama 0 kararıyla doldur):

```markdown
- **Durum:** Umut tasarımı onayladı (2026-11-24); uygulandı. Game Mode: Aşama 0 kararı [A|B|C] (3.5'in sonu). Geliştirme motoru güncel; Release paketi bir sonraki sürümle yenilenir.
```

Görev 1 Adım 7'de `IsProcessorFeaturePresent` 0 kaldıysa, spec'in "### AVX" bölümünün son maddesinin arkasına şunu ekle:

```markdown
- Wine'ın `IsProcessorFeaturePresent(PF_AVX…)` sonucu ayar açıkken de 0 (Wine ayrıca XSAVE desteğine bakıyor). Oyunların çoğu doğrudan CPUID'ye baktığı için ayar yine işe yarıyor.
```

- [ ] **Adım 7: Commit**

```bash
git add README.md docs/superpowers/specs/2026-11-24-oyun-performansi-design.md
git commit -m "README ve spec: oyun performansı uygulandı

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
