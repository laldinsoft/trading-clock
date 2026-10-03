#!/bin/bash
# Renders the icon and packs Resources/AppIcon.icns (all macOS sizes) and docs/icon.png.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=icon/out
rm -rf "$OUT"; mkdir -p "$OUT/AppIcon.iconset"
swift icon/make-icon.swift "$OUT/icon-1024.png"
for s in 16 32 128 256 512; do
    sips -z $s $s "$OUT/icon-1024.png" --out "$OUT/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z $d $d "$OUT/icon-1024.png" --out "$OUT/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$OUT/AppIcon.iconset" -o Resources/AppIcon.icns
sips -z 512 512 "$OUT/icon-1024.png" --out docs/icon.png >/dev/null
echo "Wrote Resources/AppIcon.icns and docs/icon.png"
