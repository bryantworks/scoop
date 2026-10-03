import AppKit
import KeyboardShortcuts
import SwiftUI
import TextGrabCore

struct SettingsView: View {
  let smartPaste: SmartPasteController

  @State private var launchAtLogin = LoginItem.isEnabled
  @State private var loginItemMessage: String?
  @AppStorage(SmartPasteController.enabledKey) private var smartPasteEnabled = false
  @AppStorage(SmartPasteController.historySizeKey) private var historySize =
    ClipboardHistory.defaultCapacity
  @State private var accessibilityGranted = SystemAccessibilityPermission().isGranted()
  @State private var shortcutConflicts: Set<KeyboardShortcuts.Name> = []

  var body: some View {
    Form {
      Section {
        // The Recorder warns when a shortcut is reserved by macOS or used by a menu;
        // shortcutRecorder also warns when two scoop shortcuts share keys.
        shortcutRecorder("Capture text:", name: .captureText)
        Toggle("Launch scoop at login", isOn: $launchAtLogin)
          .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
        if let loginItemMessage {
          Text(loginItemMessage).font(.caption).foregroundStyle(.secondary)
        }
        Text(
          "Text is recognized on this Mac. Nothing is sent anywhere, and screenshots are deleted right away."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Section {
        Toggle(isOn: $smartPasteEnabled) {
          Text("Smart Paste")
          Text("Keep a history of what you copy, and paste earlier items with a shortcut.")
        }
        .onChange(of: smartPasteEnabled) {
          smartPaste.applySetting()
          refreshPermission()
          refreshShortcutConflicts()
        }
        if smartPasteEnabled {
          permissionStatus
          shortcutRecorder("Clipboard history:", name: .smartPasteSwitcher)
          ForEach(KeyboardShortcuts.Name.smartPastePositions, id: \.position) { shortcut in
            shortcutRecorder("Paste past clipboard \(shortcut.position):", name: shortcut.name)
          }
          Stepper(
            "Remember \(historySize) items", value: $historySize,
            in: ClipboardHistory.allowedCapacities
          )
          .onChange(of: historySize) { smartPaste.applyHistorySize() }
          Text(
            "The history stays in memory on this Mac and is cleared when scoop quits or Smart Paste is turned off. Passwords copied from password managers are skipped."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 440)
    .fixedSize()
    .onAppear { refreshShortcutConflicts() }
    // Coming back from System Settings after granting the permission updates the status.
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in refreshPermission() }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
      _ in refreshPermission()
    }
  }

  @ViewBuilder private var permissionStatus: some View {
    if accessibilityGranted {
      Label("Accessibility permission is on", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    } else {
      HStack {
        Label(
          "scoop needs Accessibility permission to paste",
          systemImage: "exclamationmark.triangle.fill"
        )
        .foregroundStyle(.orange)
        Spacer()
        Button("Open System Settings") {
          if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
          {
            NSWorkspace.shared.open(url)
          }
        }
      }
    }
  }

  /// A shortcut recorder, with a warning under it when another scoop shortcut uses the same keys.
  @ViewBuilder private func shortcutRecorder(_ title: String, name: KeyboardShortcuts.Name)
    -> some View
  {
    KeyboardShortcuts.Recorder(title, name: name) { _ in refreshShortcutConflicts() }
    if shortcutConflicts.contains(name) {
      Text("Another scoop shortcut uses these keys. Both will run.")
        .font(.caption)
        .foregroundStyle(.orange)
    }
  }

  /// Smart Paste's shortcuts only count while it's on: they're inactive otherwise.
  private func refreshShortcutConflicts() {
    var names: [KeyboardShortcuts.Name] = [.captureText]
    if smartPasteEnabled {
      names.append(.smartPasteSwitcher)
      names += KeyboardShortcuts.Name.smartPastePositions.map(\.name)
    }
    shortcutConflicts = conflictingNames(
      names.map { (name: $0, key: KeyboardShortcuts.getShortcut(for: $0)) })
  }

  private func refreshPermission() {
    accessibilityGranted = SystemAccessibilityPermission().isGranted()
  }

  private func setLaunchAtLogin(_ enabled: Bool) {
    do {
      try LoginItem.setEnabled(enabled)
      loginItemMessage =
        LoginItem.needsApproval
        ? "Approve scoop in System Settings → General → Login Items." : nil
    } catch {
      loginItemMessage = "Couldn't change the login setting: \(error.localizedDescription)"
      launchAtLogin = LoginItem.isEnabled
    }
  }
}

@MainActor
final class SettingsWindowController {
  private let smartPaste: SmartPasteController
  private var window: NSWindow?

  init(smartPaste: SmartPasteController) {
    self.smartPaste = smartPaste
  }

  func show() {
    if window == nil {
      let hosting = NSHostingController(rootView: SettingsView(smartPaste: smartPaste))
      // Resize the window as the Smart Paste options appear and disappear.
      hosting.sizingOptions = [.preferredContentSize]
      let window = NSWindow(contentViewController: hosting)
      window.title = "scoop Settings"
      window.styleMask = [.titled, .closable]
      window.isReleasedWhenClosed = false
      window.center()
      self.window = window
    }
    NSApp.activate()
    window?.makeKeyAndOrderFront(nil)
  }
}
