# Releasing Trading Clock

A release is a notarized `TradingClock.dmg` attached to a GitHub Release. The
README's download link points at `releases/latest/download/TradingClock.dmg`,
so publishing a release is all it takes for new downloads to get it.

Signing uses the **Laldinsoft Ltd** team (`A8F2K75G7M`) and its
**Developer ID Application** certificate, the same one DayScribe uses.

## Publishing a release

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in
   `Resources/Info.plist`.
2. In `CHANGELOG.md`, rename `## Unreleased` to `## X.Y.Z — YYYY-MM-DD`. That
   section becomes the release notes.
3. Commit, then tag and push:

   ```sh
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```

The **Release** workflow checks the tag matches `Info.plist`, runs
`scripts/release.sh`, and publishes the release. Notarization uploads the app
twice (the app, then the disk image), so expect 10–20 minutes.

## Releasing from a Mac instead

With the Developer ID certificate in your keychain and notary credentials
stored once:

```sh
xcrun notarytool store-credentials laldinsoft-notary \
  --key AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer <issuer id>
make release
gh release create vX.Y.Z dist/TradingClock.dmg dist/TradingClock.dmg.sha256 \
  --title "Trading Clock X.Y.Z" --notes-file <(awk '/^## /{n++} n==1' CHANGELOG.md | tail -n +2)
```

`TRADING_CLOCK_NOTARY_PROFILE` selects a different profile name.

## Repository secrets

The same five secrets as DayScribe, on this repository or the organisation.
`scripts/set-release-secrets.sh` sets all five from the `.p12` and `.p8` in
`~/keys`, asking only for the `.p12` password and the Issuer ID:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | The Developer ID certificate and key exported from Keychain Access as `.p12`, base64-encoded |
| `DEVELOPER_ID_P12_PASSWORD` | The password chosen when exporting the `.p12` |
| `NOTARY_KEY_P8` | The full text of the App Store Connect API key, `AuthKey_XXXXXXXXXX.p8` |
| `NOTARY_KEY_ID` | That key's Key ID |
| `NOTARY_ISSUER_ID` | The Issuer ID shown above the keys list in App Store Connect |
