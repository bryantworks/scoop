import AppKit
import KeyboardShortcuts
import TextGrabCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusMenu: StatusMenu?
  private var coordinator: CaptureCoordinator?
  private let settings = SettingsWindowController()

  func applicationDidFinishLaunching(_ notification: Notification) {
    coordinator = CaptureCoordinator(
      permission: SystemScreenPermission(),
      capture: ScreencaptureService(),
      recognizer: VisionTextRecognizer(),
      clipboard: PasteboardWriter(),
      feedback: FeedbackHUD()
    )
    statusMenu = StatusMenu(
      onCapture: { [weak self] in self?.capture() },
      onSettings: { [weak self] in self?.settings.show() }
    )
    // Key *up*, so the hotkey's modifier keys are released before the crosshair appears.
    KeyboardShortcuts.onKeyUp(for: .captureText) { [weak self] in
      Task { @MainActor in self?.capture() }
    }
  }

  private func capture() {
    guard let coordinator else { return }
    Task { await coordinator.trigger() }
  }
}
