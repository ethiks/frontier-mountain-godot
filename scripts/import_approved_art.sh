#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="https://frontier-mountain-approved-art.onrender.com"
DEST="assets/approved_sprites/crops"
mkdir -p "$DEST"
while IFS= read -r name; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  echo "Importing approved sprite: $name"
  curl --fail --location --retry 3 --silent --show-error "$ROOT/$name.webp?v=062a" -o "$DEST/$name.webp"
  test -s "$DEST/$name.webp"
done < assets/approved_sprites/approved_crops.txt
echo "Approved sprite crops imported into Godot project."
