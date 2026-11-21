#!/bin/zsh
# Wine motoruna Wine Gecko ile Wine Mono'yu ekler (share/wine/gecko, share/wine/mono).
# CX 26.3.0'ın beklediği sürümler: Gecko 2.47.4 (dlls/appwiz.cpl/addons.c GECKO_VERSION), Mono 10.4.1 (MONO_VERSION).
# Bunlar motorda yoksa mshtml ekranda görünmeyen "Wine Gecko Installer" penceresinde sonsuza dek bekler,
# .NET isteyen programlar da çalışmaz (EA App kurulumu ikisine birden takılıyordu). Motorda olunca Gecko
# yerinde kullanılır; wineboot yalnız Mono'nun küçük destek paketini kurar, indirme ya da pencere açılmaz.
#
# Kullanım: Scripts/motor-eklentileri.sh [motor klasörü]   (varsayılan ~/WineEngines/WineCX26.3.0-DXMT0.80)
set -euo pipefail
MOTOR="${1:-$HOME/WineEngines/WineCX26.3.0-DXMT0.80}"
if [ ! -x "$MOTOR/bin/wine" ]; then
  echo "error: Wine motoru bulunamadı: $MOTOR"
  exit 1
fi
GECICI=$(mktemp -d)
trap 'rm -rf "$GECICI"' EXIT

# $1 share/wine altındaki klasör, $2 arşivin açtığı klasör, $3 arşiv adresi, $4 arşivin SHA-256'sı
ekle() {
  local hedef="$MOTOR/share/wine/$1" klasor="$2" adres="$3" sha="$4"
  local dosya="$GECICI/${adres:t}"
  if [ -d "$hedef/$klasor" ]; then
    echo "Zaten var: $hedef/$klasor"
    return
  fi
  curl -sSfL -o "$dosya" "$adres"
  echo "$sha  $dosya" | shasum -a 256 -c - >/dev/null
  tar -xJf "$dosya" -C "$GECICI"
  mkdir -p "$hedef"
  mv "$GECICI/$klasor" "$hedef/"
  echo "Eklendi: $hedef/$klasor"
}

ekle gecko wine-gecko-2.47.4-x86 \
  https://dl.winehq.org/wine/wine-gecko/2.47.4/wine-gecko-2.47.4-x86.tar.xz \
  2cfc8d5c948602e21eff8a78613e1826f2d033df9672cace87fed56e8310afb6
ekle gecko wine-gecko-2.47.4-x86_64 \
  https://dl.winehq.org/wine/wine-gecko/2.47.4/wine-gecko-2.47.4-x86_64.tar.xz \
  fd88fc7e537d058d7a8abf0c1ebc90c574892a466de86706a26d254710a82814
ekle mono wine-mono-10.4.1 \
  https://dl.winehq.org/wine/wine-mono/10.4.1/wine-mono-10.4.1-x86.tar.xz \
  a16606ef0724202e6a6848ece6e0cbba64d11e2f11aefe744af1d93c6d9f99bb
