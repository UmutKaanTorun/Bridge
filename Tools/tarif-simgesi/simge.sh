#!/bin/sh
# Bir Windows programının simgesini tarif simgesi yapar:
#   Tools/tarif-simgesi/simge.sh "<program.exe>" <tarif-id>
# → Resources/RecipeFiles/<tarif-id>/icon.png (exe'deki en büyük boyut, genelde 256 px)
set -eu
[ $# -eq 2 ] || { echo "kullanım: $0 <program.exe> <tarif-id>" >&2; exit 1; }
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
swiftc -O -o "$tmp/tarif-simgesi" Tools/tarif-simgesi/main.swift KopruCore/Sources/KopruCore/WindowsIcon.swift
"$tmp/tarif-simgesi" "$1" "$tmp/simge.ico"
mkdir -p "Resources/RecipeFiles/$2"
sips -s format png "$tmp/simge.ico" --out "Resources/RecipeFiles/$2/icon.png" >/dev/null
sips -g pixelWidth "Resources/RecipeFiles/$2/icon.png" | tail -1
