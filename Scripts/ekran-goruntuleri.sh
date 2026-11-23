#!/bin/zsh
# README'deki tanıtım ekran görüntülerini (docs/screenshots) yeniden üretir: dört ekran, açık ve koyu temada,
# her biri 3840x2160. Pencere 1520x900 punto açılır, Retina ekranda 3040x1800 piksel olarak ölçeklenmeden
# yakalanır ve uygulama simgesinin mor degradesine yerleştirilir (Tools/ekran-goruntusu).
#
#   Scripts/ekran-goruntuleri.sh
#
# Gerekenler:
# - Retina (2x) ekran. Pencere fare ya da odak hangi ekrandaysa orada açılır; o ekrana 1520x900 punto sığmalı.
# - Betiği çalıştıran uygulamaya (Terminal vb.) Ekran Kaydı izni; ilk yakalamada macOS sorar.
# - Bu Mac'te "Steam" ve "Epic Games Launcher" adlı, içinde oyun kurulu bottle'lar.
# Sayfalar Debug derlemesinin KOPRU_SAYFA ve KOPRU_SAHTE_KURULUM değişkenleriyle açılır (Kopru/AppModel.swift).
#
# Çalışırken yaklaşık bir dakika boyunca Bridge pencereleri açılıp kapanır ve odağı alır. Bu sırada klavyeye
# dokunma: yazılan harf kenar çubuğunda başka bir bottle seçer ya da arama alanına girer.
set -euo pipefail
cd "$(dirname "$0")/.."

CIKTI=docs/screenshots
APP=build/Build/Products/Debug/Bridge.app
BOTTLES="$HOME/Library/Application Support/Kopru/Bottles"
# SwiftUI ana penceresinin kayıtlı konumu. Boyut komut satırından (NSArgumentDomain) verilir; uygulama
# pencereyi kapatırken bunu kalıcı ayarlara da yazıyor, betik sonunda eski değer geri konur.
ANAHTAR='NSWindow Frame SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<Kopru.ContentView, SwiftUI._EnvironmentKeyWritingModifier<Swift.Optional<Kopru.AppModel>>>, SwiftUI._FlexFrameLayout>-1-AppWindow-1'
PENCERE_BOYUTU=1520x900

GECICI=$(mktemp -d)
ESKI_KONUM=$(defaults read dev.kopru.Kopru "$ANAHTAR" 2>/dev/null || true)
ACIK_PID=""
temizle() {
  [ -n "$ACIK_PID" ] && kill "$ACIK_PID" 2>/dev/null || true
  if [ -n "$ESKI_KONUM" ]; then
    defaults write dev.kopru.Kopru "$ANAHTAR" "$ESKI_KONUM"
  else
    defaults delete dev.kopru.Kopru "$ANAHTAR" 2>/dev/null || true
  fi
  rm -rf "$GECICI"
}
trap temizle EXIT

# Gereken bottle'lar var mı? Yoksa uygulama sessizce ilk bottle'ı açar, görüntü yanlış olur.
for ad in "Steam" "Epic Games Launcher"; do
  bulundu=0
  for bilgi in "$BOTTLES"/*/kopru.json(N); do
    [ "$(plutil -extract name raw -o - "$bilgi" 2>/dev/null)" = "$ad" ] && bulundu=1
  done
  if [ $bulundu = 0 ]; then
    echo "error: \"$ad\" adlı bottle yok ($BOTTLES)"
    exit 1
  fi
done

echo "Debug derlemesi…"
xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Debug -derivedDataPath build build -quiet
swiftc -O -o "$GECICI/ekran-goruntusu" Tools/ekran-goruntusu/main.swift
mkdir -p "$CIKTI"

# cek <dosya adı> <acik|koyu> <KOPRU_SAYFA> [KOPRU_SAHTE_KURULUM]
# → docs/screenshots/<dosya adı>-light.png ya da -dark.png (README <picture> ile temaya göre seçer)
cek() {
  local ad=$1 tema=$2 sayfa=$3 sahte=${4:-}
  local gorunum=(-NSRequiresAquaSystemAppearance YES) ek=light
  [ "$tema" = koyu ] && { gorunum=(-AppleInterfaceStyle Dark); ek=dark; }
  local deneme once i p pencere boyut sonuc
  for deneme in 1 2 3; do
    # Zaten açık Bridge'ler (ör. Xcode'dan çalışan) dokunulmadan kalır; pgrep hiç bulamazsa 1 döner.
    once=" $(pgrep -f "$APP/Contents/MacOS/Bridge" | tr '\n' ' ' || true) "
    open -n -F --env "KOPRU_SAYFA=$sayfa" --env "KOPRU_SAHTE_KURULUM=$sahte" "$APP" --args \
      -"$ANAHTAR" "520 270 ${PENCERE_BOYUTU/x/ } 0 0 2560 1410" -ApplePersistenceIgnoreState YES "${gorunum[@]}"
    # Pencere belirince kısa bir süre içeriğin (simgeler) çizilmesi beklenir, sonra hemen yakalanır: odak
    # başka bir uygulamaya geçerse pencere griye döner, uzun beklemek bu olasılığı artırıyor.
    ACIK_PID="" pencere="" boyut=""
    for i in {1..40}; do
      sleep 0.25
      if [ -z "$ACIK_PID" ]; then
        for p in $(pgrep -f "$APP/Contents/MacOS/Bridge" || true); do
          [[ $once == *" $p "* ]] || ACIK_PID=$p
        done
      fi
      [ -n "$ACIK_PID" ] && read pencere boyut <<< "$("$GECICI/ekran-goruntusu" pencere "$ACIK_PID" 2>/dev/null || true)"
      [ -n "$pencere" ] && break
    done
    if [ -z "$ACIK_PID" ] || [ -z "$pencere" ]; then
      echo "error: Bridge penceresi açılmadı"
      exit 1
    fi
    sleep 1.2
    read pencere boyut <<< "$("$GECICI/ekran-goruntusu" pencere "$ACIK_PID" 2>/dev/null || true)"
    sonuc=0
    if [ "$boyut" != "$PENCERE_BOYUTU" ]; then
      echo "  pencere $boyut açıldı, $PENCERE_BOYUTU bekleniyordu (ekrana sığıyor mu?)"
      sonuc=3
    fi
    [ $sonuc = 0 ] && { "$GECICI/ekran-goruntusu" yakala "$pencere" "$GECICI/$ad-$ek.png" >/dev/null || sonuc=$?; }
    kill "$ACIK_PID" 2>/dev/null || true
    while kill -0 "$ACIK_PID" 2>/dev/null; do sleep 0.2; done
    ACIK_PID=""
    if [ $sonuc = 0 ]; then
      if [ "$(sips -g pixelWidth "$GECICI/$ad-$ek.png" | awk '/pixelWidth/ {print $2}')" != 3040 ]; then
        echo "error: pencere Retina olmayan bir ekranda açıldı; 3040 piksel genişlik bekleniyordu"
        exit 1
      fi
      "$GECICI/ekran-goruntusu" yerlestir "$GECICI/$ad-$ek.png" "$CIKTI/$ad-$ek.png" "$tema"
      echo "Hazır: $CIKTI/$ad-$ek.png"
      return
    fi
    if [ $sonuc = 2 ]; then
      # Pencere etkin değil: odak başka bir uygulamaya geçti ya da öndeki uygulama odağı bırakmadı
      # (ör. Wine'daki Steam). Finder öne alınınca bir sonraki denemede bırakır.
      echo "  $ad ($tema): pencere etkin değil, yeniden deneniyor ($deneme/3)"
      open -a Finder
      sleep 1
    else
      echo "  $ad ($tema): yeniden deneniyor ($deneme/3)"
    fi
  done
  echo "error: $ad ($tema) yakalanamadı"
  exit 1
}

for tema in acik koyu; do
  cek program-kur "$tema" kur
  cek indiriliyor "$tema" kur indiriliyor:gog-galaxy
  cek steam "$tema" "bottle:Steam"
  cek epic "$tema" "bottle:Epic Games Launcher"
done

# README başlığındaki simge: derlenmiş uygulamanın düz simgesi (Icon Composer'ın eski macOS'lar için ürettiği).
sips -s format png -Z 256 "$APP/Contents/Resources/AppIcon.icns" --out "$CIKTI/bridge-simge.png" >/dev/null
echo "Hazır: $CIKTI/bridge-simge.png"
