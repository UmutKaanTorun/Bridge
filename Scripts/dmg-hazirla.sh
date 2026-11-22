#!/bin/zsh
# Release derlemesindeki Bridge.app'ten dağıtılabilir bir disk görüntüsü hazırlar:
# uygulama + Applications kısayolu, LZMA sıkıştırmalı (ULMO; macOS 10.15+, uygulama zaten 14+ istiyor).
#
# Önce Release derlemesi:
#   xcodebuild -project Kopru.xcodeproj -scheme Kopru -configuration Release -derivedDataPath build build
# Sonra:
#   Scripts/dmg-hazirla.sh            → build/dmg/Bridge-<sürüm>.dmg
#   Scripts/dmg-hazirla.sh <uygulama> → başka bir Bridge.app'ten
#
# İmza ad-hoc, notarization yok: başka bir Mac'te Gatekeeper ilk açılışı engeller
# (Finder'da sağ tık → Aç, ya da Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç).
set -euo pipefail
cd "$(dirname "$0")/.."

APP=${1:-build/Build/Products/Release/Bridge.app}
if [ ! -x "$APP/Contents/MacOS/Bridge" ]; then
  echo "error: Release uygulaması bulunamadı: $APP"
  exit 1
fi
if [ ! -x "$APP/Contents/Resources/Motor/bin/wine" ]; then
  echo "error: Uygulamada motor yok (Debug derlemesi olabilir; motor yalnız Release'te pakete girer): $APP"
  exit 1
fi
codesign --verify --strict "$APP" || { echo "error: Uygulamanın imzası tutarsız: $APP"; exit 1; }

SURUM=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
CIKTI="build/dmg/Bridge-$SURUM.dmg"
GECICI=$(mktemp -d)
trap 'rm -rf "$GECICI"' EXIT

# Görüntünün içeriği: uygulama (APFS kopyası, yer kaplamaz) ve Applications'a sürükle-bırak kısayolu.
mkdir -p "$GECICI/icerik" "$(dirname "$CIKTI")"
cp -cR "$APP" "$GECICI/icerik/Bridge.app"
ln -s /Applications "$GECICI/icerik/Applications"

hdiutil create -volname "Bridge $SURUM" -srcfolder "$GECICI/icerik" -format ULMO -ov "$CIKTI" >/dev/null
hdiutil verify "$CIKTI" >/dev/null

echo "Hazır: $CIKTI ($(du -h "$CIKTI" | cut -f1); uygulama $(du -sh "$APP" | cut -f1))"
echo "SHA-256: $(shasum -a 256 "$CIKTI" | cut -d' ' -f1)"
