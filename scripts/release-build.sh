#!/usr/bin/env bash
# CI entry point: universal build, sign with the Text Grab certificate, zip + checksum into dist/.
# Env: VERSION, SIGNING_CERT_P12_BASE64, SIGNING_CERT_PASSWORD
set -euo pipefail
cd "$(dirname "$0")/.."

: "${VERSION:?VERSION is required}"
: "${SIGNING_CERT_P12_BASE64:?SIGNING_CERT_P12_BASE64 secret is missing}"
: "${SIGNING_CERT_PASSWORD:?SIGNING_CERT_PASSWORD secret is missing}"

P12="$(mktemp -d)/signing.p12"
printf '%s' "$SIGNING_CERT_P12_BASE64" | base64 --decode >"$P12"
eval "$(scripts/import-cert.sh "$P12" "$SIGNING_CERT_PASSWORD")"
rm -f "$P12"
trap 'security delete-keychain "$KEYCHAIN_PATH"' EXIT

UNIVERSAL=1 SIGN_IDENTITY="$SIGN_IDENTITY" SIGN_KEYCHAIN="$KEYCHAIN_PATH" scripts/bundle.sh "$VERSION"

# (`lipo -verify_arch` misparses its arguments in Xcode 27's lipo, so compare `-archs` instead.)
ARCHS=" $(lipo -archs "dist/Text Grab.app/Contents/MacOS/TextGrab") "
if [[ "$ARCHS" != *" arm64 "* || "$ARCHS" != *" x86_64 "* ]]; then
  echo "Expected a universal (arm64 + x86_64) binary, got:$ARCHS" >&2
  exit 1
fi
REQUIREMENT="$(codesign -d -r- "dist/Text Grab.app" 2>&1)"
echo "$REQUIREMENT"
if ! grep -q 'certificate .* = H"' <<<"$REQUIREMENT"; then
  echo "Designated requirement is not pinned to the Text Grab certificate" >&2
  exit 1
fi

cd dist
rm -f TextGrab.zip TextGrab.zip.sha256
ditto -c -k --keepParent "Text Grab.app" TextGrab.zip
shasum -a 256 TextGrab.zip >TextGrab.zip.sha256
echo "Packaged dist/TextGrab.zip ($VERSION)"
