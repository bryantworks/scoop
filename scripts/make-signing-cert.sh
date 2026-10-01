#!/usr/bin/env bash
# One-time: create the free self-signed "Text Grab Signing" code-signing certificate.
# Output goes OUTSIDE the repo (default ~/TextGrabSigning). Back that folder up somewhere safe:
# losing it means every teammate has to grant Screen Recording permission again.
# Usage: scripts/make-signing-cert.sh [output-dir]
set -euo pipefail

OUT="${1:-$HOME/TextGrabSigning}"
NAME="Text Grab Signing"

if [[ -e "$OUT/TextGrabSigning.p12" ]]; then
  echo "Refusing to overwrite existing $OUT/TextGrabSigning.p12" >&2
  exit 1
fi
mkdir -p "$OUT"
chmod 700 "$OUT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
prompt = no
x509_extensions = ext
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# /usr/bin/openssl is LibreSSL; its PKCS#12 defaults (3DES/SHA-1) are what `security import` accepts.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "$TMP/cert.cnf" -keyout "$TMP/key.pem" -out "$OUT/TextGrabSigning.cer.pem"

PASSWORD="$(/usr/bin/openssl rand -base64 24)"
/usr/bin/openssl pkcs12 -export -name "$NAME" \
  -inkey "$TMP/key.pem" -in "$OUT/TextGrabSigning.cer.pem" \
  -out "$OUT/TextGrabSigning.p12" -passout "pass:$PASSWORD"
printf '%s' "$PASSWORD" >"$OUT/password.txt"
chmod 600 "$OUT"/*

echo "Created $OUT/TextGrabSigning.p12 (password in $OUT/password.txt)."
echo "Back up $OUT somewhere safe. Never commit it."
