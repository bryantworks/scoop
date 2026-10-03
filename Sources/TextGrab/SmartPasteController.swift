import Foundation
import KeyboardShortcuts
import TextGrabCore

/// Turns Smart Paste on and off: the clipboard history, its polling timer and the paste
/// shortcuts. While it's off nothing is monitored and the shortcuts aren't registered, so
/// other apps get ⌃⇧2…⌃⇧6 and ⌃⇧U/L/T.
@MainActor
final class SmartPasteController {
  static let enabledKey = "smartPasteEnabled"
  static let historySizeKey = "smartPasteHistorySize"
  /// Reading `changeCount` is a cheap integer read; contents are read only when it changes.
  private static let pollInterval: TimeInterval = 0.5
  /// Time for the target app to read the clipboard after ⌘V, before the next paste changes it.
  private static let settleDelay = Duration.milliseconds(150)

  /// Lets the switcher panel hand keyboard focus back to your app before ⌘V.
  private static let switcherCloseDelay = Duration.milliseconds(50)

  private let feedback: any Feedback
  private let switcher = ClipboardSwitcher()
  private(set) var coordinator: SmartPasteCoordinator?
  private var pollTimer: Timer?
  private var switcherKeyHeld = false

  init(feedback: any Feedback) {
    self.feedback = feedback
    UserDefaults.standard.register(defaults: [
      Self.historySizeKey: ClipboardHistory.defaultCapacity
    ])
    switcher.onChoose = { [weak self] position in self?.pasteFromSwitcher(position) }
  }

  static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

  /// Starts or stops to match the saved setting (off by default).
  func applySetting() {
    if Self.isEnabled { start() } else { stop() }
  }

  /// Applies a new saved history size to the running history.
  func applyHistorySize() {
    coordinator?.setHistoryCapacity(UserDefaults.standard.integer(forKey: Self.historySizeKey))
  }

  /// Opens the switcher (or closes it if it's open), e.g. from the menu bar.
  func toggleSwitcher() {
    guard let coordinator else { return }
    if switcher.isOpen {
      switcher.close()
    } else {
      coordinator.tick()  // include a copy made since the last poll
      switcher.open(items: coordinator.history.items)
    }
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
    coordinator.setHistoryCapacity(UserDefaults.standard.integer(forKey: Self.historySizeKey))
    coordinator.requestPermissionIfNeeded()

    // Carbon delivers hotkey events on the main thread; handling them synchronously keeps each
    // key-down/key-up pair in order.
    KeyboardShortcuts.onKeyDown(for: .smartPasteSwitcher) { [weak self] in
      MainActor.assumeIsolated { self?.switcherKeyDown() }
    }
    KeyboardShortcuts.onKeyUp(for: .smartPasteSwitcher) { [weak self] in
      MainActor.assumeIsolated { self?.switcherKeyHeld = false }
    }
    for (position, name) in KeyboardShortcuts.Name.smartPastePositions {
      KeyboardShortcuts.onKeyDown(for: name) { [weak self, weak coordinator] in
        MainActor.assumeIsolated {
          self?.switcher.close()  // otherwise ⌘V would land in the switcher's search box
          coordinator?.keyDown(position: position)
        }
      }
      KeyboardShortcuts.onKeyUp(for: name) { [weak coordinator] in
        MainActor.assumeIsolated { coordinator?.keyUp(position: position) }
      }
    }
    for (textCase, name) in KeyboardShortcuts.Name.smartPasteCases {
      KeyboardShortcuts.onKeyDown(for: name) { [weak self, weak coordinator] in
        MainActor.assumeIsolated {
          self?.switcher.close()
          coordinator?.keyDown(converting: textCase)
        }
      }
      KeyboardShortcuts.onKeyUp(for: name) { [weak coordinator] in
        MainActor.assumeIsolated { coordinator?.keyUp(converting: textCase) }
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
    switcher.close()
    KeyboardShortcuts.removeHandler(for: .smartPasteSwitcher)
    for (_, name) in KeyboardShortcuts.Name.smartPastePositions {
      KeyboardShortcuts.removeHandler(for: name)
    }
    for (_, name) in KeyboardShortcuts.Name.smartPasteCases {
      KeyboardShortcuts.removeHandler(for: name)
    }
    coordinator = nil
  }

  /// ⌃⇧1 opens the switcher, or closes it if it's already open. Auto-repeat is ignored.
  private func switcherKeyDown() {
    guard !switcherKeyHeld else { return }
    switcherKeyHeld = true
    toggleSwitcher()
  }

  private func pasteFromSwitcher(_ position: Int) {
    Task { [weak self] in
      try? await Task.sleep(for: Self.switcherCloseDelay)
      self?.coordinator?.paste(position: position)
    }
  }
}
