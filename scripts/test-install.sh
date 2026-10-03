#!/usr/bin/env bash
# Tests install.sh against a fake local release. Never touches /Applications or the running app.
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'chmod -R u+w "$WORK"; rm -rf "$WORK"' EXIT
APPS="$WORK/My Apps" # a space in the path on purpose
APP="$APPS/scoop.app"
SYSTEM_APPS="$WORK/System Apps" # stand-ins for /Applications and ~/Applications
USER_APPS="$WORK/User Apps"

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

# Like run_installer, but lets install.sh pick between the two stand-in folders. HOME is moved
# too, so nothing can reach the real ~/Applications.
run_installer_auto() {
  # An installer that ignored these variables would use the real /Applications.
  if ! grep -q TEXTGRAB_SYSTEM_APPS install.sh || ! grep -q TEXTGRAB_USER_APPS install.sh; then
    fail "install.sh doesn't support TEXTGRAB_SYSTEM_APPS/TEXTGRAB_USER_APPS; not running it"
  fi
  HOME="$WORK/home" \
    TEXTGRAB_TEST_MODE=1 \
    TEXTGRAB_RELEASE_URL="file://$WORK/release" \
    TEXTGRAB_SYSTEM_APPS="$SYSTEM_APPS" \
    TEXTGRAB_USER_APPS="$USER_APPS" \
    bash install.sh
}

marker() { cat "${1:-$APP}/Contents/marker"; }

fake_installed() { # $1 = folder, $2 = marker
  mkdir -p "$1/scoop.app/Contents"
  echo "$2" >"$1/scoop.app/Contents/marker"
}

reset_auto_dirs() {
  chmod -R u+w "$SYSTEM_APPS" "$USER_APPS" 2>/dev/null || true
  rm -rf "$SYSTEM_APPS" "$USER_APPS"
  mkdir -p "$SYSTEM_APPS"
}

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

# 9. A failed copy during an update leaves the installed app in place. A fake `ditto` unpacks
#    the download normally but fails to copy it into the Applications folder (like a full disk).
make_release v5
run_installer >/dev/null || fail "install before the failed-copy test exited non-zero"
mkdir -p "$WORK/bin"
cat >"$WORK/bin/ditto" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == -x* || "$1" == -c* ]]; then exec /usr/bin/ditto "$@"; fi
echo "ditto: No space left on device" >&2
exit 1
EOF
chmod +x "$WORK/bin/ditto"
make_release v6
if PATH="$WORK/bin:$PATH" run_installer >/dev/null 2>&1; then fail "a failed copy should fail"; fi
[[ "$(marker)" == v5 ]] || fail "a failed copy must leave the installed app in place"
[[ -z "$(find "$APPS" -maxdepth 1 -name '.scoop.app.*')" ]] || fail "a failed copy left a staging folder"
run_installer --uninstall >/dev/null || fail "uninstall after the failed-copy test exited non-zero"

# 10. A fresh install goes to the shared folder when it's writable, else the user's folder.
reset_auto_dirs
make_release v7
run_installer_auto >/dev/null || fail "fresh auto install exited non-zero"
[[ "$(marker "$SYSTEM_APPS/scoop.app")" == v7 ]] || fail "fresh install should use the shared folder"
reset_auto_dirs
chmod a-w "$SYSTEM_APPS"
run_installer_auto >/dev/null || fail "fresh install with a read-only shared folder exited non-zero"
[[ "$(marker "$USER_APPS/scoop.app")" == v7 ]] ||
  fail "fresh install should fall back to the user's folder"

# 11. An update replaces the installed copy where it is, even if the shared folder is writable now.
reset_auto_dirs
fake_installed "$USER_APPS" old
run_installer_auto >/dev/null || fail "update of a user-folder install exited non-zero"
[[ "$(marker "$USER_APPS/scoop.app")" == v7 ]] || fail "update should replace the user-folder copy"
[[ ! -e "$SYSTEM_APPS/scoop.app" ]] || fail "update must not add a second copy"

# 12. With copies in both folders, an update leaves exactly one (in the shared folder).
reset_auto_dirs
fake_installed "$SYSTEM_APPS" old
fake_installed "$USER_APPS" old
run_installer_auto >/dev/null || fail "update with two copies exited non-zero"
[[ "$(marker "$SYSTEM_APPS/scoop.app")" == v7 ]] || fail "update should replace the shared copy"
[[ ! -e "$USER_APPS/scoop.app" ]] || fail "update should remove the duplicate copy"

# 13. If the installed copy's folder can't be written, stop instead of installing a second copy.
reset_auto_dirs
fake_installed "$SYSTEM_APPS" old
chmod a-w "$SYSTEM_APPS"
if run_installer_auto >/dev/null 2>&1; then fail "an unwritable install folder should fail"; fi
[[ "$(marker "$SYSTEM_APPS/scoop.app")" == old ]] || fail "the installed copy must be left alone"
[[ ! -e "$USER_APPS/scoop.app" ]] || fail "must not install a second copy in the user's folder"
reset_auto_dirs

# 14. The first-run text tells users to reopen scoop from Applications: once scoop quits, its
#     menu bar icon is gone.
grep -q "reopen it from your Applications folder" install.sh ||
  fail "first-run text should say to reopen scoop from the Applications folder"

echo "install.sh: all checks passed"
