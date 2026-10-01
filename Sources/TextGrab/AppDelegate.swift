import AppKit
import CoreGraphics

/// SPIKE (Task 2, throwaway): a menu bar item that runs screencapture, used to check that
/// Screen Recording permission is attributed to Text Grab (spec risk 3) and carries over
/// across signed builds (spec risk 2). Replaced in Task 7.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    item.button?.image = NSImage(
      systemSymbolName: "text.viewfinder", accessibilityDescription: "Text Grab")
    let menu = NSMenu()
    let spike = NSMenuItem(
      title: "Spike: Capture to Desktop", action: #selector(spikeCapture), keyEquivalent: "")
    spike.target = self
    menu.addItem(spike)
    menu.addItem(.separator())
    menu.addItem(
      NSMenuItem(
        title: "Quit Text Grab", action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"))
    item.menu = menu
    statusItem = item
  }

  @objc private func spikeCapture() {
    guard CGPreflightScreenCaptureAccess() else {
      _ = CGRequestScreenCaptureAccess()
      return
    }
    let output = FileManager.default.homeDirectoryForCurrentUser
      .appending(path: "Desktop/textgrab-spike.png")
    let process = Process()
    process.executableURL = URL(filePath: "/usr/sbin/screencapture")
    process.arguments = ["-i", "-x", output.path]
    try? process.run()
  }
}
