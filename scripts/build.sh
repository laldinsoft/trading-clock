#!/bin/bash
# Builds dist/Trading Clock.app. Set TRADING_CLOCK_ARCHS to "host" for a faster
# single-architecture build; the default is a universal binary.
set -euo pipefail
cd "$(dirname "$0")/.."
ARCHS="${TRADING_CLOCK_ARCHS:-universal}"
case "$ARCHS" in universal) ARCHS="arm64 x86_64" ;; host) ARCHS="$(uname -m)" ;; esac
FLAGS=(); for a in $ARCHS; do FLAGS+=(--arch "$a"); done

swift build -c release "${FLAGS[@]}"
BIN_DIR="$(swift build -c release "${FLAGS[@]}" --show-bin-path)"
APP="$PWD/dist/Trading Clock.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/TradingClock" "$APP/Contents/MacOS/TradingClock"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/Sounds Resources/Speech "$APP/Contents/Resources/"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
IDENTITY="${TRADING_CLOCK_SIGNING_IDENTITY:--}"
SIGN=(--force --sign "$IDENTITY" --options runtime --entitlements Resources/TradingClock.entitlements)
[[ "$IDENTITY" == - ]] || SIGN+=(--timestamp)
/usr/bin/codesign "${SIGN[@]}" "$APP"
/usr/bin/codesign --verify --strict "$APP"
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/TradingClock"))"
