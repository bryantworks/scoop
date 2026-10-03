# Manual test checklist

Run before each release, on a real Mac, using the build being released.

- [ ] **Automated tests on a real Mac:** `swift test` passes locally. (CI skips the Vision text-recognition tests because GitHub's virtual Macs can't run them.)

- [ ] **Fresh install:** on a Mac (or user account) that has never had scoop, the README install command works and the menu bar icon appears.
- [ ] **Permission flow:** the first ⌘⇧2 shows the permission explanation; after granting it and reopening the app, capture works.
- [ ] **Basic capture:** ⌘⇧2 → drag over text → paste matches, and "Copied ✓" appears.
- [ ] **Multi-line:** a paragraph keeps its line breaks.
- [ ] **Cancel:** ⌘⇧2 → Esc shows nothing and leaves the clipboard unchanged.
- [ ] **No text:** dragging over a blank area shows "No text found" and leaves the clipboard unchanged.
- [ ] **Multiple monitors:** a capture on a secondary display works.
- [ ] **Hotkey change:** a new shortcut in Settings works immediately, the menu shows it, and it survives a relaunch.
- [ ] **Launch at login:** turn it on, log out and back in, and scoop is running.
- [ ] **Update keeps permission:** with the previous release installed and permitted, run the install command; capture works without a new permission prompt.
- [ ] **Uninstall:** the uninstall command removes the app, its settings, and its Screen Recording and Accessibility entries.

### Smart Paste

- [ ] **Off by default:** on a fresh install, there's no Accessibility prompt, ⌃⇧2 reaches the frontmost app, and the menu has no Clipboard History item.
- [ ] **Turning it on:** the Settings toggle asks for Accessibility; after granting, Settings shows the green status line.
- [ ] **Countdown:** copy six words one at a time, then hold ⌃⇧ and tap 6 six times; they paste in copy order.
- [ ] **Fast repeats and held keys:** tapping ⌃⇧2 quickly alternates between the last two items; holding ⌃⇧6 down pastes once.
- [ ] **Case shortcuts:** copy "the quick brown fox" in TextEdit; ⌃⇧U, ⌃⇧L and ⌃⇧T paste "THE QUICK BROWN FOX", "the quick brown fox" and "The Quick Brown Fox"; ⌘V afterward still pastes the original.
- [ ] **Case shortcuts keep the clipboard:** copy a file in Finder, press ⌃⇧U in TextEdit (the file name pastes in caps), then ⌘V in a Finder folder still pastes the file. With an image or a password manager copy on the clipboard, ⌃⇧U beeps and pastes nothing.
- [ ] **Skips secrets:** a password copied from a password manager isn't in the history.
- [ ] **Captures and images:** ⌘⇧2 text and a ⌘⌃⇧4 screenshot both join the history and paste back.
- [ ] **Switcher:** ⌃⇧1 opens over the current app without taking focus; search, ↑/↓ and Return paste into that app; Esc and clicking away close it. Works over a full-screen app.
- [ ] **Shortcuts:** a rebound shortcut works and survives a relaunch; the ⓧ clears one.
- [ ] **Missing permission:** with Accessibility off, a shortcut shows the explanation alert and Settings shows the orange status.
- [ ] **Turning it off:** shortcuts pass through to other apps again and the history is cleared.
- [ ] **Update keeps Accessibility:** with the previous release installed and permitted, run the install command; Smart Paste works without a new prompt.
