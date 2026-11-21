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
if [ ! -f "$SRC/orijinal-grafik/x86_64-windows/d3d11.dll" ]; then
  echo "error: Motorda orijinal-grafik/ yok; program başına wined3d (ör. Rockstar Launcher) çalışmaz: $SRC"
  exit 1
fi
# Gecko ve Mono (share/wine/gecko, share/wine/mono; ~330 MB) pakette olmalı: yoksa IE denetimi gömen programlar
# görünmeyen Gecko indirme penceresinde takılır, .NET isteyenler (EA App kurulumu) düşer.
for eklenti in gecko/wine-gecko-2.47.4-x86 gecko/wine-gecko-2.47.4-x86_64 mono/wine-mono-10.4.1; do
  if [ ! -d "$SRC/share/wine/$eklenti" ]; then
    echo "error: Motorda share/wine/$eklenti yok; Scripts/motor-eklentileri.sh ile ekle: $SRC"
    exit 1
  fi
done
mkdir -p "$DST"
# orijinal-grafik/ (Wine'ın kendi d3d11/dxgi/d3d10core'u, 3 MB) pakette kalır: ntdll yaması bottle
# ayarındaki programlar için onu DLL yolunun başına koyar (Tools/motor-yamalari/ntdll-program-basina-wined3d.patch).
rsync -a --delete --exclude 'include/' "$SRC/" "$DST/"
echo "Motor kopyalandı: $DST"
