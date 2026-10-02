#!/usr/bin/env bash
# Tests install.sh against a fake local release. Never touches /Applications or the running app.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
APPS="$WORK/My Apps" # a space in the path on purpose
APP="$APPS/scoop.app"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_release() { # $1 = marker written inside the fake app
  rm -rf "$WORK/release" "$WORK/build"
  mkdir -p "$WORK/release" "$WORK/build/scoop.app/Contents"
  echo "$1" >"$WORK/build/scoop.app/Contents/marker"
  (cd "$WORK/build" && ditto -c -k --keepParent "scoop.app" "$WORK/release/TextGrab.zip")
  (cd "$WORK/release" && shasum -a 256 TextGrab.zip >TextGrab.zip.sha256)
}

run_installer() {
  TEXTGRAB_TEST_MODE=1 \
    TEXTGRAB_RELEASE_URL="file://$WORK/release" \
    TEXTGRAB_INSTALL_DIR="$APPS" \
    bash install.sh "$@"
}

marker() { cat "$APP/Contents/marker"; }

mkdir -p "$APPS"

# 1. Fresh install
make_release v1
run_installer >/dev/null || fail "fresh install exited non-zero"
[[ "$(marker)" == v1 ]] || fail "fresh install did not place the app"

# 2. Update replaces the existing app
make_release v2
run_installer >/dev/null || fail "update exited non-zero"
[[ "$(marker)" == v2 ]] || fail "update did not replace the app"

# 3. Checksum mismatch aborts and leaves the existing install untouched
make_release v3
printf '%064d  TextGrab.zip\n' 0 >"$WORK/release/TextGrab.zip.sha256"
if run_installer >/dev/null 2>&1; then fail "checksum mismatch should fail"; fi
[[ "$(marker)" == v2 ]] || fail "checksum mismatch must not touch the existing install"

# 4. Uninstall removes the app; uninstalling again is a successful no-op
run_installer --uninstall >/dev/null || fail "uninstall exited non-zero"
[[ ! -e "$APP" ]] || fail "uninstall left the app behind"
run_installer --uninstall >/dev/null || fail "uninstall when not installed should succeed"

# 5. Installing over a pre-rename "Text Grab.app" removes it, leaving only scoop
mkdir -p "$APPS/Text Grab.app/Contents"
make_release v4
run_installer >/dev/null || fail "install over legacy app exited non-zero"
[[ "$(marker)" == v4 ]] || fail "install over legacy app did not place the app"
[[ ! -e "$APPS/Text Grab.app" ]] || fail "install left the legacy Text Grab.app behind"
run_installer --uninstall >/dev/null || fail "uninstall after legacy install exited non-zero"

# 6. Unknown options are rejected
if run_installer --bogus >/dev/null 2>&1; then fail "unknown option should fail"; fi

# 7. The installer quits a running app with a signal, never AppleScript: an AppleScript
#    "quit app" can show an Automation permission prompt and make the update look hung.
if grep -q osascript install.sh; then fail "install.sh must not use osascript"; fi

# 8. Only uninstall resets permissions: an install or update must keep Screen Recording and
#    Accessibility granted.
if awk '/^do_install\(\)/,/^}/' install.sh | grep -q tccutil; then
  fail "install/update must not reset permissions"
fi
awk '/^do_uninstall\(\)/,/^}/' install.sh | grep -q "tccutil reset Accessibility" ||
  fail "uninstall should reset the Accessibility permission"

echo "install.sh: all checks passed"
