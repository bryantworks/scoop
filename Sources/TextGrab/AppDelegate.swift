import AppKit
import KeyboardShortcuts
import TextGrabCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusMenu: StatusMenu?
  private var coordinator: CaptureCoordinator?
  private let feedback = FeedbackHUD()
  private lazy var smartPaste = SmartPasteController(feedback: feedback)
  private lazy var settings = SettingsWindowController(smartPaste: smartPaste)

  func applicationDidFinishLaunching(_ notification: Notification) {
    coordinator = CaptureCoordinator(
      permission: SystemScreenPermission(),
      capture: ScreencaptureService(),
      recognizer: VisionTextRecognizer(),
      clipboard: PasteboardWriter(),
      feedback: feedback
    )
    statusMenu = StatusMenu(
      onCapture: { [weak self] in self?.capture() },
      onClipboardHistory: { [weak self] in self?.smartPaste.toggleSwitcher() },
      onSettings: { [weak self] in self?.settings.show() }
    )
    // Key *up* fires when the main key lifts; the shortcut's modifiers may still be down. That's
    // harmless except for ⌃: held into the drag, it makes the drag a Control-click, and the
    // selection never finishes. (The default ⌘⇧2 is unaffected.)
    KeyboardShortcuts.onKeyUp(for: .captureText) { [weak self] in
      Task { @MainActor in self?.capture() }
    }
    smartPaste.applySetting()
  }

  private func capture() {
    guard let coordinator else { return }
    Task { await coordinator.trigger() }
  }
}
