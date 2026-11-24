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
