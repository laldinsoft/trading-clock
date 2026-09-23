#!/bin/bash
# Copies the release signing material into this repository's GitHub Actions
# secrets, so pushing a v* tag can build, notarize and publish a release.
# Run it once, on a Mac with `gh` signed in:
#   scripts/set-release-secrets.sh
# It never prints a secret. Override the defaults with environment variables:
#   REPO   GitHub repository            (laldinsoft/trading-clock)
#   P12    Developer ID cert + key      (~/keys/Developer_Cert.p12)
#   P8     App Store Connect API key    (the AuthKey_*.p8 in ~/keys)
#   NOTARY_ISSUER_ID  skips the issuer prompt
set -euo pipefail
REPO="${REPO:-laldinsoft/trading-clock}"
P12="${P12:-$HOME/keys/Developer_Cert.p12}"
P8="${P8:-$(ls "$HOME"/keys/AuthKey_*.p8 2>/dev/null | head -1)}"
[[ -f "$P12" ]] || { echo "Certificate not found: $P12" >&2; exit 1; }
[[ -f "$P8" ]] || { echo "API key not found: set P8 to the AuthKey_XXXXXXXXXX.p8 path." >&2; exit 1; }
KEY_ID="$(basename "$P8" .p8)"; KEY_ID="${KEY_ID#AuthKey_}"
gh auth status >/dev/null 2>&1 || { echo "Run 'gh auth login' first." >&2; exit 1; }

read -rsp "Password used when exporting $(basename "$P12"): " P12_PASSWORD; echo
# Check the password and that this really is the Developer ID Application certificate.
subject="$( { openssl pkcs12 -in "$P12" -nokeys -passin pass:"$P12_PASSWORD" 2>/dev/null \
           || openssl pkcs12 -in "$P12" -nokeys -passin pass:"$P12_PASSWORD" -legacy 2>/dev/null; } \
           | openssl x509 -noout -subject 2>/dev/null || true)"
[[ -n "$subject" ]] || { echo "Wrong password, or the file is not a PKCS#12 bundle." >&2; exit 1; }
[[ "$subject" == *"Developer ID Application"* ]] || {
    echo "This certificate is not a Developer ID Application identity:" >&2; echo "  $subject" >&2; exit 1
}
echo "Certificate: ${subject#*CN=}"

ISSUER="${NOTARY_ISSUER_ID:-}"
if [[ -z "$ISSUER" ]]; then
    echo "The Issuer ID is shown above the keys list at App Store Connect → Users and Access → Integrations → Keys."
    read -rp "App Store Connect Issuer ID: " ISSUER
fi
[[ "$ISSUER" =~ ^[0-9a-f-]{36}$ ]] || { echo "That does not look like an Issuer ID (a UUID)." >&2; exit 1; }

base64 -i "$P12" | gh secret set DEVELOPER_ID_P12_BASE64 -R "$REPO"
printf '%s' "$P12_PASSWORD" | gh secret set DEVELOPER_ID_P12_PASSWORD -R "$REPO"
gh secret set NOTARY_KEY_P8 -R "$REPO" < "$P8"
printf '%s' "$KEY_ID" | gh secret set NOTARY_KEY_ID -R "$REPO"
printf '%s' "$ISSUER" | gh secret set NOTARY_ISSUER_ID -R "$REPO"
echo
gh secret list -R "$REPO"
echo "Done. Pushing a v* tag now builds and publishes a release in GitHub Actions."
