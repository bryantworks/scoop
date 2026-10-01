#!/usr/bin/env bash
# Imports the signing .p12 into a new throwaway keychain and prints, shell-quoted:
#   KEYCHAIN_PATH=<path>   SIGN_IDENTITY=<SHA-1 of the certificate>
# Local use:  eval "$(scripts/import-cert.sh ~/TextGrabSigning/TextGrabSigning.p12 "$(cat ~/TextGrabSigning/password.txt)")"
# Clean up:   security delete-keychain "$KEYCHAIN_PATH"
set -euo pipefail

P12="$1"
PASSWORD="$2"
KEYCHAIN="$(mktemp -d)/textgrab-signing.keychain-db"
KEYCHAIN_PASSWORD="$(/usr/bin/openssl rand -base64 24)"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$P12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null

# Put the new keychain on the user search list (keeping the existing ones) so codesign finds the key.
existing=()
while IFS= read -r kc; do
  existing+=("$(echo "$kc" | xargs)")
done < <(security list-keychains -d user)
security list-keychains -d user -s "$KEYCHAIN" "${existing[@]}"

HASH="$(security find-certificate -c "Text Grab Signing" -Z "$KEYCHAIN" | awk '/SHA-1 hash:/ {print $NF}')"
if [[ -z "$HASH" ]]; then
  echo "Could not find the Text Grab Signing certificate in the imported .p12" >&2
  exit 1
fi

printf 'KEYCHAIN_PATH=%q\n' "$KEYCHAIN"
printf 'SIGN_IDENTITY=%q\n' "$HASH"
