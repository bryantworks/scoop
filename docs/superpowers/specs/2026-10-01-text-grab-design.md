# Text Grab — Design Spec

**Date:** 2026-10-01
**Status:** Draft, awaiting review
**Repo:** `bryantworks/text-grab`

## 1. Goal

A macOS menu bar utility similar to TextSniper: press a global hotkey, drag to select any area of the screen, and the text in that area is recognized on-device and copied to the clipboard.

**Who it's for:** the author's daily use first, and teammates (not necessarily developers) second. Teammates must be able to install and update it with a single Terminal command.

**Success criteria**

- Hotkey → drag → text on the clipboard within about one second of releasing the mouse for a typical selection.
- A teammate can go from nothing to working in under five minutes: one pasted command plus granting the Screen Recording permission once.
- Updating keeps the Screen Recording permission, so teammates don't have to grant it again.
- No network access, no telemetry, and no screenshots kept.

## 2. Scope

**In scope (v1)**

- Global hotkey (default ⌘⇧2), customizable in Settings.
- Drag-to-select capture using macOS's built-in selector.
- On-device text recognition (Apple Vision) with automatic language detection and line breaks preserved.
- Copy the result to the clipboard, with a brief toast saying "Copied ✓", "No text found" or an error.
- Menu bar icon with: Capture Text (shows the current shortcut), Settings…, About, Quit. No Dock icon.
- Settings window: hotkey picker and a launch-at-login switch.
- One-command install, update and uninstall script.
- Automated signed release builds via GitHub Actions.

**Out of scope (v1)**

- QR or barcode reading, translation, text-to-speech, capture history.
- App Store distribution and Apple notarization (no paid Apple Developer account).
- A custom-drawn selection overlay (revisit only if the built-in selector falls short).
- macOS versions older than 14 (Sonoma).

## 3. Key decisions

| Decision | Choice | Why |
|---|---|---|
| Language and UI | Swift 6, AppKit plus a small SwiftUI Settings window | Native, small, direct access to Vision |
| Build system | Swift Package Manager plus a bundling script; no Xcode project | Builds with only the command line tools installed; no Xcode download for anyone |
| Screen capture and selection | `/usr/sbin/screencapture -i -x <file>` | Reliable, handles multiple monitors, much less code; ScreenCaptureKit not needed |
| Text recognition | Vision text recognition, accurate level, automatic language detection, language correction on | Same engine as Live Text, offline, high quality |
| Global hotkey | [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) | Well maintained, includes a recorder UI, stores settings in UserDefaults, no Accessibility permission needed |
| Launch at login | `SMAppService.mainApp` | Apple's current API (macOS 13+) |
| Code signing | Free self-signed certificate "Text Grab Signing" | Gives a stable code identity so the Screen Recording permission carries over between updates, at no cost |
| Distribution | GitHub Releases plus `install.sh` via `curl … \| bash` | `curl` downloads usually aren't flagged as "downloaded from the internet", so the "unidentified developer" block is avoided |
| Repo visibility | **Public** | Lets the install command download without logging in to GitHub. The repo contains no secrets; the certificate lives in encrypted GitHub secrets |
| Minimum macOS | 14 (Sonoma) | Modern APIs; assumed to cover the team |
| CPU architecture | Universal (arm64 + x86_64) | Supports both Apple Silicon and Intel teammates |

## 4. Architecture

### 4.1 Package layout

```
Package.swift
Sources/
  TextGrabCore/          # logic library, fully unit-tested
    CaptureCoordinator.swift
    CaptureService.swift
    TextRecognizer.swift
    ReadingOrder.swift
    ClipboardWriter.swift
    Feedback.swift        # protocol only
    ScreenPermission.swift
  TextGrab/              # app shell (executable target)
    main.swift / AppDelegate.swift
    StatusMenu.swift
    SettingsView.swift
    FeedbackHUD.swift
    LoginItem.swift
    Shortcuts.swift       # KeyboardShortcuts.Name definitions
Tests/
  TextGrabCoreTests/
Resources/
  Info.plist
  AppIcon.icns
scripts/
  bundle.sh              # wraps the built binary into "Text Grab.app"
  make-signing-cert.sh   # one-time self-signed certificate generation
install.sh
README.md               # teammate-facing install and usage guide
.github/workflows/
  ci.yml
  release.yml
docs/
  releasing.md
  testing.md
```

### 4.2 Components

Each unit has one job and a small interface. Anything that touches the system sits behind a protocol so the coordinator can be tested with stand-ins.

| Unit | Interface (sketch) | Responsibility |
|---|---|---|
| `ScreenPermission` | `protocol ScreenPermission { func isGranted() -> Bool; func request() }` | Wraps `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess` |
| `CaptureService` | `protocol CaptureService { func captureSelection() async throws -> CGImage? }` (`nil` = cancelled) | Runs `screencapture -i -x` to a unique temporary file, loads the image, and always deletes the file |
| `TextRecognizer` | `protocol TextRecognizer { func recognize(_ image: CGImage) async throws -> String }` | Runs Vision; returns the text in reading order, joined with `\n`; returns `""` when there's no text |
| `ReadingOrder` | `static func sort(_ lines: [RecognizedLine]) -> [RecognizedLine]` | Pure function: sorts lines top to bottom, then left to right, grouping lines whose vertical centers fall within half a line height into one row |
| `ClipboardWriter` | `protocol ClipboardWriter { func write(_ text: String) }` | Clears `NSPasteboard.general` and writes plain text |
| `Feedback` | `protocol Feedback { func show(_ event: FeedbackEvent) }` where `FeedbackEvent = .copied, .noText, .captureFailed, .recognitionFailed, .permissionNeeded` | Implemented in the app by `FeedbackHUD` (a borderless toast near the cursor that hides itself after about 1.2 s; the permission case shows an alert with an "Open System Settings" button) |
| `CaptureCoordinator` | `@MainActor final class CaptureCoordinator { func trigger() async }` | Runs the flow in §5; ignores triggers while a capture is already running |
| `LoginItem` | `var isEnabled: Bool { get set }` | Wraps `SMAppService.mainApp` register/unregister/status |
| `StatusMenu` | — | `NSStatusItem` with Capture Text (shows the shortcut), Settings…, About, Quit |
| `SettingsView` | — | SwiftUI: `KeyboardShortcuts.Recorder` and a launch-at-login switch |

`Info.plist` sets `LSUIElement = true` (no Dock icon), `CFBundleIdentifier = com.bryantworks.textgrab`, `LSMinimumSystemVersion = 14.0`, and the version from the release tag.

## 5. Capture flow

1. The hotkey fires and calls `CaptureCoordinator.trigger()`. If a capture is already running, it returns immediately.
2. If `ScreenPermission.isGranted()` is false, it calls `request()`, shows `.permissionNeeded` and stops. (Without the permission, macOS captures only the desktop wallpaper, which would otherwise show up as "no text found".)
3. `CaptureService.captureSelection()` shows the crosshair. Esc or an empty selection returns `nil`, and the coordinator stops silently.
4. `TextRecognizer.recognize(image)` runs off the main thread.
5. If the result, trimmed of whitespace, is empty, it shows `.noText` and **does not** touch the clipboard.
6. Otherwise `ClipboardWriter.write(text)` runs and `.copied` is shown.
7. The temporary file is deleted in every case (inside `CaptureService`, via `defer`).

## 6. Error handling

**Rules:** never overwrite the clipboard on failure; always tell the user something, except when they cancelled.

| Condition | Behavior |
|---|---|
| User cancelled | Nothing shown |
| Screen Recording permission missing | Alert explaining the permission, with an "Open System Settings" button that deep-links to Privacy & Security → Screen Recording |
| `screencapture` exits with an error or the image can't be loaded | Toast: "Couldn't capture screen" |
| Vision throws | Toast: "Couldn't read text" |
| Hotkey already used by another app | Warning shown under the hotkey picker in Settings |

All failures are recorded with `os.Logger` (subsystem `com.bryantworks.textgrab`) so they can be inspected in Console.app.

## 7. Build, release and install

### 7.1 One-time signing setup (done by the maintainer, guided)

1. Run `scripts/make-signing-cert.sh`. It creates a self-signed certificate named "Text Grab Signing" that is valid for code signing for 10 years, and exports a `.p12` file plus a password.
2. Store these as repo secrets: `SIGNING_CERT_P12_BASE64` and `SIGNING_CERT_PASSWORD`.
3. Keep a backup of the `.p12` file somewhere safe (outside the repo). Losing it causes the next release to have a new code identity, and every teammate has to grant the Screen Recording permission again.

### 7.2 Release pipeline (`release.yml`)

Triggered by pushing a tag `v*.*.*`. It runs on GitHub's `macos-latest` machines:

1. `swift build -c release --arch arm64 --arch x86_64`
2. `scripts/bundle.sh` assembles `Text Grab.app`, filling in the version in `Info.plist` from the tag.
3. Imports the certificate into a temporary keychain, then runs `codesign --force --sign "Text Grab Signing" --timestamp=none "Text Grab.app"`.
4. Runs `codesign --verify --deep --strict` as a check.
5. `ditto -c -k --keepParent` → `TextGrab-<version>.zip`, plus a `.sha256` checksum file.
6. Creates a GitHub Release with both files attached.

### 7.3 CI (`ci.yml`)

Runs on every pull request and every push to `main`: `swift build`, `swift test`, `shellcheck install.sh scripts/*.sh`, and a `swift-format lint` check. Pushes to `main` also make a signed build. Pull requests never get the signing certificate.

### 7.4 Install script (`install.sh`)

The README command:

```
curl -fsSL https://raw.githubusercontent.com/bryantworks/text-grab/main/install.sh | bash
```

What it does:

1. Checks the macOS version (14 or newer) and exits with a clear message otherwise.
2. Finds the latest release through the public GitHub API, downloads the zip and `.sha256` into a temporary directory, and checks the checksum. It stops if they don't match.
3. Quits a running Text Grab if there is one (`osascript -e 'quit app "Text Grab"'`).
4. Replaces `/Applications/Text Grab.app`. If it can't write there, it falls back to `~/Applications`.
5. Clears the "downloaded from the internet" flag defensively (`xattr -dr com.apple.quarantine`).
6. Opens the app and prints next steps: grant the Screen Recording permission, then press ⌘⇧2.

`--uninstall` quits the app, removes it, and removes its settings (`defaults delete com.bryantworks.textgrab`). Running the command again with no flags performs an update.

## 8. Testing

### 8.1 Automated (Swift Testing, `TextGrabCoreTests`)

- **TextRecognizer** (real Vision, no stand-ins). Test images are drawn at runtime with Core Text, so no binary fixtures are needed. Cases:
  - a single line
  - several lines (line breaks preserved)
  - white on dark
  - small (12 pt) text
  - a blank image, which returns `""`
  Assertions compare normalized text: whitespace trimmed and comparison case-insensitive where OCR noise is expected.
- **ReadingOrder**: made-up boxes for ordinary lines, two columns, slightly tilted rows, and items at the same height ordered left to right.
- **CaptureCoordinator**, with stand-in implementations of every protocol. Cases:
  - success (clipboard written, `.copied` shown)
  - cancel (nothing written, nothing shown)
  - no text (clipboard untouched, `.noText`)
  - capture throws (clipboard untouched, `.captureFailed`)
  - recognizer throws (clipboard untouched, `.recognitionFailed`)
  - permission missing (`request()` called, `.permissionNeeded`, capture never called)
  - a second trigger while one is running is ignored
- **Scripts**: `shellcheck` in CI.

### 8.2 Manual (`docs/testing.md`, run before each release)

- Fresh install via the one-line command on a Mac that has never had the app.
- Permission flow: the first capture shows the explanation and Settings opens; after granting, capture works.
- Multiple monitors: select on the secondary display.
- Changing the hotkey in Settings takes effect immediately and survives a relaunch.
- Launch at login: switch it on, log out and back in, and the app is running.
- Update: install the previous release, grant the permission, install the new release, and the permission is still granted.
- Uninstall removes the app and its settings.

## 9. Repo conventions

These are added to the project `CLAUDE.md` and apply to this repo instead of the global HubSpot/Node conventions:

- Swift 6 with strict concurrency checking; `swift-format` for formatting.
- Swift Testing for tests; every new logic unit in `TextGrabCore` gets tests.
- All changes go through PRs; `main` is protected and requires CI to pass.
- No network calls, telemetry, or keeping screenshots in the app.
- No secrets in the repo; signing material lives only in GitHub secrets and the maintainer's backup.

## 10. Risks to check first

These come first in the implementation plan. If any fails, stop and revisit the design before building on it.

1. **Self-signed signing on GitHub's Mac machines:** a self-signed code-signing certificate can be imported into a temporary keychain on `macos-latest` and used by `codesign` without manual trust steps.
2. **Permission carry-over:** two different builds signed with the same self-signed certificate keep the Screen Recording permission (the code identity stays stable).
3. **`screencapture` permission attribution:** when our app launches `screencapture`, macOS attributes the Screen Recording permission to Text Grab, not to `screencapture`, and captures window contents once it's granted.
4. **Swift Testing with only the command line tools:** `swift test` runs Swift Testing suites without full Xcode installed, both locally and in CI.
5. **KeyboardShortcuts without Xcode:** the package and its SwiftUI recorder build with SwiftPM using only the command line tools.

## 11. One-time rollout steps (require maintainer confirmation)

- Make `bryantworks/text-grab` public, after checking that no sensitive files are in the commit history.
- Turn on branch protection for `main` (require a PR and passing CI).
- Create the signing certificate and add the repo secrets (§7.1).
- Cut `v1.0.0` and share the README install command with teammates.
