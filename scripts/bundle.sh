#!/usr/bin/env bash
# Builds Scoop and assembles + signs dist/Scoop.app.
# Usage: scripts/bundle.sh [version]          (default 0.0.0-dev)
# Env:   SIGN_IDENTITY  codesign identity: "-" (ad-hoc, default) or the SHA-1 from import-cert.sh
#        SIGN_KEYCHAIN  keychain holding that identity (optional)
#        UNIVERSAL=1    arm64 + x86_64 build (needs full Xcode; used in CI)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-0.0.0-dev}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP="dist/Scoop.app"

build_args=(-c release)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  build_args+=(--arch arm64 --arch x86_64)
fi
swift build "${build_args[@]}"
BIN_DIR="$(swift build "${build_args[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/TextGrab" "$APP/Contents/MacOS/TextGrab"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist >"$APP/Contents/Info.plist"

# SwiftPM resource bundles (e.g. KeyboardShortcuts' localizations).
find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;

sign_args=(--force --sign "$SIGN_IDENTITY" --timestamp=none)
if [[ -n "${SIGN_KEYCHAIN:-}" ]]; then
  sign_args+=(--keychain "$SIGN_KEYCHAIN")
fi
codesign "${sign_args[@]}" "$APP"
codesign --verify --deep --strict "$APP"

echo "Built $APP (version $VERSION)"
