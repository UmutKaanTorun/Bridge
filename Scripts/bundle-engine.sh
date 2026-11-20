#!/bin/zsh
# Release derlemesinde Wine motorunu Kopru.app/Contents/Resources/Motor'a kopyalar.
# Debug'da hiçbir şey yapmaz; uygulama motoru ~/WineEngines'ten okur.
set -euo pipefail
if [ "${CONFIGURATION:-Debug}" != "Release" ]; then
  echo "Debug derlemesi: motor kopyalanmıyor."
  exit 0
fi
SRC="${KOPRU_MOTOR_KAYNAK:-$HOME/WineEngines/WineCX26.3.0-DXMT0.80}"
DST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/Motor"
if [ ! -x "$SRC/bin/wine" ]; then
  echo "error: Wine motoru bulunamadı: $SRC"
  exit 1
fi
mkdir -p "$DST"
rsync -a --delete --exclude 'include/' --exclude 'orijinal-grafik/' "$SRC/" "$DST/"
echo "Motor kopyalandı: $DST"
