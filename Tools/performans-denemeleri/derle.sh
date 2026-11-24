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
