import AppKit
import KeyboardShortcuts

@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let onCapture: () -> Void
  private let onClipboardHistory: () -> Void
  private let onSettings: () -> Void
  private let clipboardHistory = NSMenuItem(
    title: "Clipboard History…", action: #selector(clipboardHistoryClicked), keyEquivalent: "")

  init(
    onCapture: @escaping () -> Void, onClipboardHistory: @escaping () -> Void,
    onSettings: @escaping () -> Void
  ) {
    self.onCapture = onCapture
    self.onClipboardHistory = onClipboardHistory
    self.onSettings = onSettings
    super.init()

    statusItem.button?.image = NSImage(
      systemSymbolName: "text.viewfinder", accessibilityDescription: "scoop")

    let menu = NSMenu()
    let capture = NSMenuItem(
      title: "Capture Text", action: #selector(captureClicked), keyEquivalent: "")
    capture.target = self
    capture.setShortcut(for: .captureText)  // shows, and stays in sync with, the chosen hotkey
    menu.addItem(capture)
    clipboardHistory.target = self
    clipboardHistory.setShortcut(for: .smartPasteSwitcher)
    menu.addItem(clipboardHistory)
    menu.addItem(.separator())

    let settings = NSMenuItem(
      title: "Settings…", action: #selector(settingsClicked), keyEquivalent: ",")
    settings.target = self
    menu.addItem(settings)

    let about = NSMenuItem(
      title: "About scoop", action: #selector(aboutClicked), keyEquivalent: "")
    about.target = self
    menu.addItem(about)
    menu.addItem(.separator())

    menu.addItem(
      NSMenuItem(
        title: "Quit scoop", action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"))
    menu.delegate = self
    statusItem.menu = menu
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    clipboardHistory.isHidden = !SmartPasteController.isEnabled
  }

  @objc private func captureClicked() { onCapture() }

  @objc private func clipboardHistoryClicked() { onClipboardHistory() }

  @objc private func settingsClicked() { onSettings() }

  @objc private func aboutClicked() {
    NSApp.activate()
    NSApp.orderFrontStandardAboutPanel(nil)
  }
}
