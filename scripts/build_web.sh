#!/usr/bin/env bash
set -euo pipefail
VERSION=4.4.1
mkdir -p /tmp/godot-dist web "$HOME/.local/share/godot/export_templates/$VERSION.stable"
curl -fL --retry 3 "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_linux.x86_64.zip" -o /tmp/godot-dist/godot.zip
unzip -oq /tmp/godot-dist/godot.zip -d /tmp/godot-dist
chmod +x "/tmp/godot-dist/Godot_v${VERSION}-stable_linux.x86_64"
curl -fL --retry 3 "https://github.com/godotengine/godot/releases/download/${VERSION}-stable/Godot_v${VERSION}-stable_export_templates.tpz" -o /tmp/godot-dist/templates.tpz
unzip -oq /tmp/godot-dist/templates.tpz -d /tmp/godot-dist
cp /tmp/godot-dist/templates/* "$HOME/.local/share/godot/export_templates/$VERSION.stable/"
bash scripts/import_approved_art.sh
/tmp/godot-dist/Godot_v${VERSION}-stable_linux.x86_64 --headless --path . --editor --quit
mkdir -p /tmp/frontier-smoke-forestry /tmp/frontier-smoke-progression
# Separate user:// test dirs prevent autosaves from contaminating later tests.
rm -rf /tmp/frontier-smoke-forestry/* /tmp/frontier-smoke-progression/*
XDG_DATA_HOME=/tmp/frontier-smoke-forestry /tmp/godot-dist/Godot_v${VERSION}-stable_linux.x86_64 --headless --path . --script res://tests/forestry_smoke.gd
XDG_DATA_HOME=/tmp/frontier-smoke-progression /tmp/godot-dist/Godot_v${VERSION}-stable_linux.x86_64 --headless --path . --script res://tests/progression_smoke.gd
/tmp/godot-dist/Godot_v${VERSION}-stable_linux.x86_64 --headless --path . --export-release 'Web' web/index.html
