import AppKit
import KeyboardShortcuts

@MainActor
final class StatusMenu: NSObject {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let onCapture: () -> Void
  private let onSettings: () -> Void

  init(onCapture: @escaping () -> Void, onSettings: @escaping () -> Void) {
    self.onCapture = onCapture
    self.onSettings = onSettings
    super.init()

    statusItem.button?.image = NSImage(
      systemSymbolName: "text.viewfinder", accessibilityDescription: "Text Grab")

    let menu = NSMenu()
    let capture = NSMenuItem(
      title: "Capture Text", action: #selector(captureClicked), keyEquivalent: "")
    capture.target = self
    capture.setShortcut(for: .captureText)  // shows, and stays in sync with, the chosen hotkey
    menu.addItem(capture)
    menu.addItem(.separator())

    let settings = NSMenuItem(
      title: "Settings…", action: #selector(settingsClicked), keyEquivalent: ",")
    settings.target = self
    menu.addItem(settings)

    let about = NSMenuItem(
      title: "About Text Grab", action: #selector(aboutClicked), keyEquivalent: "")
    about.target = self
    menu.addItem(about)
    menu.addItem(.separator())

    menu.addItem(
      NSMenuItem(
        title: "Quit Text Grab", action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"))
    statusItem.menu = menu
  }

  @objc private func captureClicked() { onCapture() }

  @objc private func settingsClicked() { onSettings() }

  @objc private func aboutClicked() {
    NSApp.activate()
    NSApp.orderFrontStandardAboutPanel(nil)
  }
}
