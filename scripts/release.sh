#!/bin/bash
# Builds a Developer ID signed, notarized and stapled universal Trading Clock.app,
# wraps it in a drag-to-Applications disk image, and notarizes that too, so the
# download opens with a plain double-click on any Mac.
#
# Signing: TRADING_CLOCK_SIGNING_IDENTITY, or the only "Developer ID Application"
# identity in the keychain.
# Notarization, either:
#   TRADING_CLOCK_NOTARY_PROFILE  a `notarytool store-credentials` profile
#                                 (default: laldinsoft-notary), or
#   TRADING_CLOCK_NOTARY_KEY, TRADING_CLOCK_NOTARY_KEY_ID, TRADING_CLOCK_NOTARY_ISSUER
#                                 an App Store Connect API key (.p8 path), for CI.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${TRADING_CLOCK_SIGNING_IDENTITY:-}" ]]; then
    IDENTITIES="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | sort -u)"
    case "$(printf '%s' "$IDENTITIES" | grep -c .)" in
        1) TRADING_CLOCK_SIGNING_IDENTITY="$IDENTITIES" ;;
        0) echo "No Developer ID Application certificate in the keychain." >&2; exit 1 ;;
        *) echo "Several Developer ID identities found; set TRADING_CLOCK_SIGNING_IDENTITY to one of:" >&2
           echo "$IDENTITIES" >&2; exit 1 ;;
    esac
fi
export TRADING_CLOCK_SIGNING_IDENTITY
[[ "$TRADING_CLOCK_SIGNING_IDENTITY" == "Developer ID Application:"* ]] || {
    echo "Releases must be signed with a Developer ID Application identity, not '$TRADING_CLOCK_SIGNING_IDENTITY'." >&2
    exit 1
}

if [[ -n "${TRADING_CLOCK_NOTARY_KEY:-}" ]]; then
    NOTARY_AUTH=(--key "$TRADING_CLOCK_NOTARY_KEY"
                 --key-id "${TRADING_CLOCK_NOTARY_KEY_ID:?TRADING_CLOCK_NOTARY_KEY_ID is required with TRADING_CLOCK_NOTARY_KEY}"
                 --issuer "${TRADING_CLOCK_NOTARY_ISSUER:?TRADING_CLOCK_NOTARY_ISSUER is required with TRADING_CLOCK_NOTARY_KEY}")
else
    NOTARY_AUTH=(--keychain-profile "${TRADING_CLOCK_NOTARY_PROFILE:-laldinsoft-notary}")
fi
# Fail before a long build if the credentials are wrong.
xcrun notarytool history "${NOTARY_AUTH[@]}" >/dev/null

# notarize FILE: uploads FILE, waits for Apple's verdict, and prints the log on failure.
notarize() {
    local file="$1" result id
    echo "Submitting $(basename "$file") for notarization (this uploads ~$(du -sh "$file" | cut -f1))…"
    result="$(xcrun notarytool submit "$file" "${NOTARY_AUTH[@]}" --wait --output-format plist)" || true
    id="$(/usr/libexec/PlistBuddy -c 'Print :id' /dev/stdin <<< "$result" 2>/dev/null || true)"
    if [[ "$(/usr/libexec/PlistBuddy -c 'Print :status' /dev/stdin <<< "$result" 2>/dev/null)" != Accepted ]]; then
        echo "Notarization failed for $(basename "$file")." >&2
        echo "$result" >&2
        [[ -z "$id" ]] || xcrun notarytool log "$id" "${NOTARY_AUTH[@]}" >&2
        exit 1
    fi
    echo "Notarized (submission $id)."
}

unset TRADING_CLOCK_ARCHS  # a release is always universal
./scripts/build.sh

APP="$PWD/dist/Trading Clock.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
for arch in arm64 x86_64; do
    lipo "$APP/Contents/MacOS/TradingClock" -verify_arch "$arch" || {
        echo "The release app has no $arch slice." >&2; exit 1
    }
done

WORK="$PWD/.build/release-staging"
rm -rf "$WORK"
mkdir -p "$WORK/dmg"

# Notarize and staple the app itself, so it opens even offline once copied out
# of the disk image.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$WORK/TradingClock.zip"
notarize "$WORK/TradingClock.zip"
xcrun stapler staple "$APP"

# The disk image keeps a stable name so the README can link to
# releases/latest/download/TradingClock.dmg.
DMG="$PWD/dist/TradingClock.dmg"
rm -f "$DMG" "$DMG.sha256"
ditto "$APP" "$WORK/dmg/Trading Clock.app"
ln -s /Applications "$WORK/dmg/Applications"
hdiutil create -volname "Trading Clock $VERSION" -srcfolder "$WORK/dmg" -fs HFS+ -format ULFO -ov "$DMG"
/usr/bin/codesign --force --sign "$TRADING_CLOCK_SIGNING_IDENTITY" --timestamp "$DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"

# Check exactly what a downloader's Gatekeeper will check.
xcrun stapler validate "$APP"
xcrun stapler validate "$DMG"
spctl --assess --type execute --verbose=2 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

(cd dist && shasum -a 256 TradingClock.dmg > TradingClock.dmg.sha256)
rm -rf "$WORK"
echo "Release $VERSION ready: $DMG"
