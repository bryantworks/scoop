import Foundation
import KeyboardShortcuts
import TextGrabCore

/// Turns Smart Paste on and off: the clipboard history, its polling timer and the paste
/// shortcuts. While it's off nothing is monitored and the shortcuts aren't registered, so
/// other apps get ⌃⇧2…⌃⇧6.
@MainActor
final class SmartPasteController {
  static let enabledKey = "smartPasteEnabled"
  /// Reading `changeCount` is a cheap integer read; contents are read only when it changes.
  private static let pollInterval: TimeInterval = 0.5
  /// Time for the target app to read the clipboard after ⌘V, before the next paste changes it.
  private static let settleDelay = Duration.milliseconds(150)

  private let feedback: any Feedback
  private(set) var coordinator: SmartPasteCoordinator?
  private var pollTimer: Timer?

  init(feedback: any Feedback) {
    self.feedback = feedback
  }

  static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

  /// Starts or stops to match the saved setting (off by default).
  func applySetting() {
    if Self.isEnabled { start() } else { stop() }
  }

  private func start() {
    guard coordinator == nil else { return }
    let coordinator = SmartPasteCoordinator(
      pasteboard: SystemPasteboard(),
      keystrokes: CGEventKeystrokeSender(),
      permission: SystemAccessibilityPermission(),
      feedback: feedback,
      settle: { try? await Task.sleep(for: Self.settleDelay) }
    )
    coordinator.requestPermissionIfNeeded()

    // Carbon delivers hotkey events on the main thread; handling them synchronously keeps each
    // key-down/key-up pair in order.
    for (position, name) in KeyboardShortcuts.Name.smartPastePositions {
      KeyboardShortcuts.onKeyDown(for: name) { [weak coordinator] in
        MainActor.assumeIsolated { coordinator?.keyDown(position: position) }
      }
      KeyboardShortcuts.onKeyUp(for: name) { [weak coordinator] in
        MainActor.assumeIsolated { coordinator?.keyUp(position: position) }
      }
    }

    let timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) {
      [weak coordinator] _ in
      MainActor.assumeIsolated { coordinator?.tick() }
    }
    timer.tolerance = 0.1
    pollTimer = timer
    self.coordinator = coordinator
  }

  /// Also forgets the history (it's only ever kept in memory).
  private func stop() {
    pollTimer?.invalidate()
    pollTimer = nil
    for (_, name) in KeyboardShortcuts.Name.smartPastePositions {
      KeyboardShortcuts.removeHandler(for: name)
    }
    coordinator = nil
  }
}
