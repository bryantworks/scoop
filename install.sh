#!/usr/bin/env bash
# scoop installer — https://github.com/bryantworks/scoop
#
#   Install or update:
#     curl -fsSL https://raw.githubusercontent.com/bryantworks/scoop/main/install.sh | bash
#   Uninstall:
#     curl -fsSL https://raw.githubusercontent.com/bryantworks/scoop/main/install.sh | bash -s -- --uninstall
set -euo pipefail

APP_NAME="scoop"
LEGACY_APP_NAME="Text Grab" # pre-rename installs; same bundle ID, removed on install/uninstall
BUNDLE_ID="com.bryantworks.textgrab"
RELEASE_URL="${TEXTGRAB_RELEASE_URL:-https://github.com/bryantworks/scoop/releases/latest/download}"
INSTALL_DIR_OVERRIDE="${TEXTGRAB_INSTALL_DIR:-}"
TEST_MODE="${TEXTGRAB_TEST_MODE:-0}"
PROCESS_NAME="${TEXTGRAB_PROCESS_NAME:-TextGrab}"
TMP_DIR=""

say() { printf '==> %s\n' "$*"; }
die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}
cleanup() { if [[ -n "$TMP_DIR" ]]; then rm -rf "$TMP_DIR"; fi; }
trap cleanup EXIT

install_dirs() {
  if [[ -n "$INSTALL_DIR_OVERRIDE" ]]; then
    echo "$INSTALL_DIR_OVERRIDE"
  else
    echo "/Applications"
    echo "$HOME/Applications"
  fi
}

choose_install_dir() {
  if [[ -n "$INSTALL_DIR_OVERRIDE" ]]; then
    echo "$INSTALL_DIR_OVERRIDE"
  elif [[ -w /Applications ]]; then
    echo "/Applications"
  else
    mkdir -p "$HOME/Applications"
    echo "$HOME/Applications"
  fi
}

quit_running_app() {
  # Tests use a dummy process name; otherwise test mode never touches a running app.
  if [[ "$TEST_MODE" == "1" && -z "${TEXTGRAB_PROCESS_NAME:-}" ]]; then return 0; fi
  if pgrep -xq "$PROCESS_NAME"; then
    say "Quitting the running scoop…"
    # A plain signal, not an AppleScript "quit app": that can trigger an Automation
    # permission prompt ("Terminal wants to control scoop") and look like a hang.
    pkill -x "$PROCESS_NAME" || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      pgrep -xq "$PROCESS_NAME" || return 0
      sleep 0.3
    done
    pkill -9 -x "$PROCESS_NAME" || true
  fi
}

remove_legacy_app() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir/$LEGACY_APP_NAME.app" ]]; then
      rm -rf "${dir:?}/$LEGACY_APP_NAME.app"
      say "Removed the old $dir/$LEGACY_APP_NAME.app"
    fi
  done < <(install_dirs)
}

check_macos() {
  local version major
  version="$(sw_vers -productVersion)"
  major="${version%%.*}"
  ((major >= 14)) || die "scoop needs macOS 14 (Sonoma) or newer. This Mac has macOS $version."
}

do_install() {
  check_macos
  TMP_DIR="$(mktemp -d)"

  say "Downloading scoop…"
  curl -fsSL "$RELEASE_URL/TextGrab.zip" -o "$TMP_DIR/TextGrab.zip" ||
    die "Download failed. Check your internet connection and try again."
  curl -fsSL "$RELEASE_URL/TextGrab.zip.sha256" -o "$TMP_DIR/TextGrab.zip.sha256" ||
    die "Couldn't download the checksum file."

  (cd "$TMP_DIR" && shasum -a 256 -c TextGrab.zip.sha256 >/dev/null 2>&1) ||
    die "The download didn't match its checksum, so nothing was changed. Please try again."

  ditto -x -k "$TMP_DIR/TextGrab.zip" "$TMP_DIR/unpacked"
  [[ -d "$TMP_DIR/unpacked/$APP_NAME.app" ]] || die "The download didn't contain $APP_NAME.app."

  local dest
  dest="$(choose_install_dir)"
  quit_running_app
  rm -rf "${dest:?}/$APP_NAME.app"
  remove_legacy_app
  ditto "$TMP_DIR/unpacked/$APP_NAME.app" "$dest/$APP_NAME.app"
  xattr -dr com.apple.quarantine "$dest/$APP_NAME.app" 2>/dev/null || true
  say "Installed $APP_NAME to $dest."

  if [[ "$TEST_MODE" != "1" ]]; then
    open "$dest/$APP_NAME.app"
    cat <<'EOF'

scoop is running — look for its icon in the menu bar.

First time only: press ⌘⇧2. macOS will ask for Screen Recording permission.
Turn on scoop in System Settings → Privacy & Security → Screen Recording,
then quit and reopen scoop from the menu bar icon.

Then: press ⌘⇧2, drag over any text, and paste. Done!

Optional: turn on Smart Paste in Settings (menu bar icon → Settings…) to paste
earlier copies with ⌃⇧1–6. It asks for Accessibility permission when you do.
EOF
  fi
}

do_uninstall() {
  quit_running_app
  local dir removed=0
  while IFS= read -r dir; do
    if [[ -d "$dir/$APP_NAME.app" ]]; then
      rm -rf "${dir:?}/$APP_NAME.app"
      say "Removed $dir/$APP_NAME.app"
      removed=1
    fi
  done < <(install_dirs)
  remove_legacy_app
  if [[ "$TEST_MODE" != "1" ]]; then
    defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
    # Best effort: also forget the permissions, so a reinstall starts fresh.
    tccutil reset ScreenCapture "$BUNDLE_ID" >/dev/null 2>&1 || true
    tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
  fi
  if ((removed)); then
    say "scoop has been uninstalled."
  else
    say "scoop wasn't installed. Nothing to do."
  fi
}

main() {
  case "${1:-}" in
    "") do_install ;;
    --uninstall) do_uninstall ;;
    *) die "Unknown option: $1 (use --uninstall, or no option to install/update)" ;;
  esac
}

# Everything above only defines functions, so a partially downloaded script does nothing.
main "$@"
