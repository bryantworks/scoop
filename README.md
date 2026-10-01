# Scoop

Press a shortcut, drag over anything on your screen, and the text is copied to your clipboard. It works on images, videos, PDFs, screen shares — anything you can see.

Everything happens on your Mac: nothing is sent anywhere, and screenshots are deleted right away.

## Install

Requires macOS 14 (Sonoma) or newer. Works on Apple Silicon and Intel Macs.

1. Open **Terminal** (press ⌘Space, type `Terminal`, press Return).
2. Paste this line and press Return:

   ```
   curl -fsSL https://raw.githubusercontent.com/mikebryantworks/scoop/main/install.sh | bash
   ```

3. **First time only:** press **⌘⇧2**. macOS asks for Screen Recording permission. Open System Settings → Privacy & Security → **Screen Recording**, turn on **Scoop**, then click the Scoop icon in the menu bar → **Quit Scoop** and reopen it from your Applications folder.

## Use

1. Press **⌘⇧2** (Command-Shift-2).
2. Drag over the text you want.
3. Paste anywhere (⌘V).

A small "Copied ✓" confirms it worked. Press **Esc** to cancel a capture.

## Settings

Click the Scoop icon in the menu bar → **Settings…** to:

- **Change the shortcut:** click the shortcut box and press the new keys.
- **Launch at login:** turn it on so Scoop is always ready. If macOS asks, approve it in System Settings → General → Login Items.

## Update

Run the same install command again. Your settings and permission are kept.

## Uninstall

```
curl -fsSL https://raw.githubusercontent.com/mikebryantworks/scoop/main/install.sh | bash -s -- --uninstall
```

Then you can remove Scoop from System Settings → Privacy & Security → Screen Recording.

## Troubleshooting

| Problem | Fix |
|---|---|
| "No text found" on text I can see | Screen Recording permission is probably off. Check System Settings → Privacy & Security → Screen Recording, then quit and reopen Scoop. |
| The shortcut does nothing | Another app may use the same shortcut. Pick a different one in Settings. Also check that the Scoop icon is in the menu bar. |
| macOS says the app "can't be opened" | You probably downloaded the zip in a browser. Use the Terminal install command instead, or go to System Settings → Privacy & Security and click **Open Anyway**. |
| Something else | Open **Console.app**, search for `com.bryantworks.textgrab`, and send the messages to the maintainer. |

## For developers

Built with Swift and SwiftPM (no Xcode project). Building needs Xcode installed (free from the App Store), but you never open it. `swift build`, `swift test`, and `scripts/bundle.sh` to make `dist/Scoop.app`. See `CLAUDE.md` for conventions and `docs/releasing.md` to cut a release.
