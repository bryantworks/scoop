# scoop

Press a shortcut, drag over anything on your screen, and the text is copied to your clipboard. It works on images, videos, PDFs and screen shares: anything you can see.

Everything happens on your Mac: nothing is sent anywhere, and screenshots are deleted right away.

## Install

Requires macOS 14 (Sonoma) or newer. Works on Apple Silicon and Intel Macs.

1. Open **Terminal** (press ⌘Space, type `Terminal`, press Return).
2. Paste this line and press Return:

   ```
   curl -fsSL https://raw.githubusercontent.com/bryantworks/scoop/main/install.sh | bash
   ```

3. **First time only:** press **⌘⇧2**. macOS asks for Screen Recording permission. Open System Settings → Privacy & Security → **Screen Recording**, turn on **scoop**, then click the scoop icon in the menu bar → **Quit scoop** and reopen it from your Applications folder.

## Use

1. Press **⌘⇧2** (Command-Shift-2).
2. Drag over the text you want.
3. Paste anywhere (⌘V).

A small "Copied ✓" confirms it worked. Press **Esc** to cancel a capture.

## Smart Paste (optional)

Smart Paste keeps a history of the last things you copied (text, formatted text and images) and pastes earlier ones with a shortcut. It's off until you turn it on.

**Turn it on:** click the scoop icon in the menu bar → **Settings…** → turn on **Smart Paste**. macOS asks for **Accessibility** permission, which scoop needs to paste for you. Turn on **scoop** in System Settings → Privacy & Security → **Accessibility**.

**Paste an earlier copy:** the item on your clipboard now is the current one. The ones before it are "past clipboard 1" (the one you copied just before), "past clipboard 2", and so on.

| Shortcut | Pastes |
|---|---|
| **⌃⇧2** (Control-Shift-2) | past clipboard 1 |
| **⌃⇧3** | past clipboard 2 |
| **⌃⇧4** | past clipboard 3 |
| **⌃⇧5** | past clipboard 4 |
| **⌃⇧6** | past clipboard 5 |

Pasting an item also puts it back on top of the history, so the others move back one place. That makes this handy trick work: **copy up to six things, then hold Control-Shift and tap 6 six times.** They paste in the order you copied them. (For three things, tap 4 three times, and so on.)

**Pick from the whole history:** press **⌃⇧1** (or click the menu bar icon → **Clipboard History…**). Type to search, use ↑/↓ to choose, and press Return to paste into the app you're in. Esc closes it.

**Privacy:** the history stays in memory on your Mac. It's never saved to disk, and it's cleared when scoop quits or you turn Smart Paste off. Passwords copied from password managers are skipped. Images larger than 25 MB aren't kept.

## Settings

Click the scoop icon in the menu bar → **Settings…** to:

- **Change a shortcut:** click the shortcut box and press the new keys. To remove a shortcut, click the ⓧ in its box.
- **Smart Paste:** turn it on or off, change its shortcuts, and choose how many items it remembers (10 unless you change it).
- **Launch at login:** turn it on so scoop is always ready. If macOS asks, approve it in System Settings → General → Login Items.

## Update

Run the same install command again. Your settings and permissions are kept.

## Uninstall

```
curl -fsSL https://raw.githubusercontent.com/bryantworks/scoop/main/install.sh | bash -s -- --uninstall
```

This also removes scoop's Screen Recording and Accessibility permissions. If scoop is still listed in System Settings → Privacy & Security → Screen Recording or Accessibility, select it and click **−** to remove it.

## Troubleshooting

| Problem | Fix |
|---|---|
| "No text found" on text I can see | Screen Recording permission is probably off. Check System Settings → Privacy & Security → Screen Recording, then quit and reopen scoop. |
| The shortcut does nothing | Another app may use the same shortcut. Pick a different one in Settings. Also check that the scoop icon is in the menu bar. |
| Smart Paste shortcuts (⌃⇧1–6) do nothing | Check Smart Paste is on in Settings. If Settings shows "scoop needs Accessibility permission to paste", click **Open System Settings** and turn on scoop. |
| Smart Paste says it needs Accessibility, but scoop is already turned on in System Settings | The entry can go stale (for example, after a reinstall). In System Settings → Privacy & Security → Accessibility, select scoop, click **−** to remove it, then turn Smart Paste off and on again in scoop's Settings and allow it when asked. |
| A Smart Paste shortcut beeps | There's nothing at that position yet. The history starts empty each time scoop opens or Smart Paste is turned on, so copy a few more things first. |
| Smart Paste pastes the wrong item in one app | Some slower apps (often Electron apps like Slack) read the clipboard late. Press the shortcuts a little more slowly in that app, and tell the maintainer which app it was. |
| macOS says the app "can't be opened" | You probably downloaded the zip in a browser. Use the Terminal install command instead, or go to System Settings → Privacy & Security and click **Open Anyway**. |
| Something else | Open **Console.app**, search for `com.bryantworks.textgrab`, and send the messages to the maintainer. |

## For developers

Built with Swift and SwiftPM (no Xcode project). Building needs Xcode installed (free from the App Store), but you never open it. `swift build`, `swift test`, and `scripts/bundle.sh` to make `dist/scoop.app`. See `CLAUDE.md` for conventions and `docs/releasing.md` to cut a release.
