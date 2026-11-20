#!/bin/zsh
# Steam aracı programını derler ve uygulamanın tarif dosyalarına koyar.
# Gerekli: Homebrew mingw-w64 (x86_64-w64-mingw32-gcc).
set -euo pipefail
cd "$(dirname "$0")"
x86_64-w64-mingw32-gcc -municode -O2 -s -o ../../Resources/RecipeFiles/steam/steamwebhelper.exe araci.c
echo "Derlendi: Resources/RecipeFiles/steam/steamwebhelper.exe"
