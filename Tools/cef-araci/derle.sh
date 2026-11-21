#!/bin/zsh
# CEF yardımcı aracılarını derler ve uygulamanın tarif dosyalarına koyar.
# Gerekli: Homebrew mingw-w64 (x86_64-w64-mingw32-gcc).
# -mwindows: pencere (GUI) programı; konsol programı olursa Wine aracıya siyah bir konsol penceresi açar.
set -euo pipefail
cd "$(dirname "$0")"

# derle <tarif> <yardımcı exe adı> <ek bayraklar>
derle() {
  local tarif=$1 ad=$2 bayraklar=$3
  local gercek="${ad%.exe}_gercek.exe"
  x86_64-w64-mingw32-gcc -municode -mwindows -O2 -s \
    "-DGERCEK_DOSYA=L\"$gercek\"" "-DEK_BAYRAKLAR=L\"$bayraklar\"" \
    -o "../../Resources/RecipeFiles/$tarif/$ad" araci.c
  echo "Derlendi: Resources/RecipeFiles/$tarif/$ad ($gercek $bayraklar)"
}

# Rockstar Games Launcher → Social Club giriş penceresi (CEF): GPU tarayıcı sürecinde.
derle rockstar SocialClubHelper.exe "--in-process-gpu"
