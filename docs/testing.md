# Manual test checklist

Run before each release, on a real Mac, using the build being released.

- [ ] **Fresh install:** on a Mac (or user account) that has never had Text Grab, the README install command works and the menu bar icon appears.
- [ ] **Permission flow:** the first ⌘⇧2 shows the permission explanation; after granting it and reopening the app, capture works.
- [ ] **Basic capture:** ⌘⇧2 → drag over text → paste matches, and "Copied ✓" appears.
- [ ] **Multi-line:** a paragraph keeps its line breaks.
- [ ] **Cancel:** ⌘⇧2 → Esc shows nothing and leaves the clipboard unchanged.
- [ ] **No text:** dragging over a blank area shows "No text found" and leaves the clipboard unchanged.
- [ ] **Multiple monitors:** a capture on a secondary display works.
- [ ] **Hotkey change:** a new shortcut in Settings works immediately, the menu shows it, and it survives a relaunch.
- [ ] **Launch at login:** turn it on, log out and back in, and Text Grab is running.
- [ ] **Update keeps permission:** with the previous release installed and permitted, run the install command; capture works without a new permission prompt.
- [ ] **Uninstall:** the uninstall command removes the app and its settings.
