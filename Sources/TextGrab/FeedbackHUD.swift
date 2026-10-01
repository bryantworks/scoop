import AppKit
import TextGrabCore

/// A short toast near the cursor for results, and an alert for the missing permission.
@MainActor
final class FeedbackHUD: Feedback {
  private var panel: NSPanel?
  private var hideTask: Task<Void, Never>?

  func show(_ event: FeedbackEvent) {
    switch event {
    case .copied: toast("Copied ✓")
    case .noText: toast("No text found")
    case .captureFailed: toast("Couldn't capture screen")
    case .recognitionFailed: toast("Couldn't read text")
    case .permissionNeeded:
      showPermissionAlert(
        message: "scoop needs Screen Recording permission",
        details: """
          scoop reads text from the area you select. Turn on scoop in \
          System Settings → Privacy & Security → Screen Recording, then quit and reopen scoop.
          """,
        settingsPane: "Privacy_ScreenCapture")
    case .accessibilityNeeded:
      showPermissionAlert(
        message: "scoop needs Accessibility permission to paste",
        details: """
          Smart Paste pastes for you by pressing ⌘V. Turn on scoop in \
          System Settings → Privacy & Security → Accessibility, then press the shortcut again. \
          If it still doesn't paste, quit and reopen scoop.
          """,
        settingsPane: "Privacy_Accessibility")
    case .nothingToPaste: NSSound.beep()
    }
  }

  private func toast(_ message: String) {
    hideTask?.cancel()
    panel?.orderOut(nil)

    let label = NSTextField(labelWithString: message)
    label.font = .systemFont(ofSize: 14, weight: .semibold)
    label.translatesAutoresizingMaskIntoConstraints = false

    let background = NSVisualEffectView()
    background.material = .hudWindow
    background.state = .active
    background.wantsLayer = true
    background.layer?.cornerRadius = 10
    background.addSubview(label)
    NSLayoutConstraint.activate([
      label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
      label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
      label.topAnchor.constraint(equalTo: background.topAnchor, constant: 10),
      label.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -10),
    ])
    let size = background.fittingSize

    let panel = NSPanel(
      contentRect: frameNearCursor(size: size),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.contentView = background
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .statusBar
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .transient]
    panel.orderFrontRegardless()
    self.panel = panel

    hideTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(1200))
      guard !Task.isCancelled else { return }
      self?.panel?.orderOut(nil)
      self?.panel = nil
    }
  }

  /// Just below and to the right of the cursor, kept fully on the cursor's screen.
  private func frameNearCursor(size: NSSize) -> NSRect {
    let mouse = NSEvent.mouseLocation
    var frame = NSRect(
      x: mouse.x + 12, y: mouse.y - size.height - 12, width: size.width, height: size.height)
    if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
      let visible = screen.visibleFrame
      frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
      frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
    }
    return frame
  }

  private func showPermissionAlert(message: String, details: String, settingsPane: String) {
    NSApp.activate()
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = details
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Cancel")
    if alert.runModal() == .alertFirstButtonReturn,
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?\(settingsPane)")
    {
      NSWorkspace.shared.open(url)
    }
  }
}
