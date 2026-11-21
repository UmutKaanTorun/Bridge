#!/bin/zsh
# CEF yardımcı aracılarını derler ve uygulamanın tarif dosyalarına koyar.
# Gerekli: Homebrew mingw-w64 (x86_64-w64-mingw32-gcc, 32 bit için i686-w64-mingw32-gcc).
# -mwindows: pencere (GUI) programı; konsol programı olursa Wine aracıya siyah bir konsol penceresi açar.
set -euo pipefail
cd "$(dirname "$0")"

# derle <tarif> <yardımcı exe adı> <ek bayraklar> [derleyici; varsayılan 64 bit]
derle() {
  local tarif=$1 ad=$2 bayraklar=$3 cc=${4:-x86_64-w64-mingw32-gcc}
  local gercek="${ad%.exe}_gercek.exe"
  mkdir -p "../../Resources/RecipeFiles/$tarif"
  $cc -municode -mwindows -O2 -s \
    "-DGERCEK_DOSYA=L\"$gercek\"" "-DEK_BAYRAKLAR=L\"$bayraklar\"" \
    -o "../../Resources/RecipeFiles/$tarif/$ad" araci.c
  echo "Derlendi: Resources/RecipeFiles/$tarif/$ad ($gercek $bayraklar, $cc)"
}

# Rockstar Games Launcher → Social Club giriş penceresi (CEF): GPU tarayıcı sürecinde.
derle rockstar SocialClubHelper.exe "--in-process-gpu"

# Epic → oyun içi EOS katmanı (CEF, ör. ilk açılıştaki hesap izni sayfası): GPU'da paylaşımlı doku
# açamıyor ("Unable to initialize SkSurface"), sayfa çizilmiyor; yazılımla çizer.
derle epic EOSOverlayRenderer-Win64-Shipping.exe "--disable-gpu"
derle epic EOSOverlayRenderer-Win32-Shipping.exe "--disable-gpu" i686-w64-mingw32-gcc
