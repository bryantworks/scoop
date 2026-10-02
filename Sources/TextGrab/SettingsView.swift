import AppKit
import KeyboardShortcuts
import SwiftUI
import TextGrabCore

struct SettingsView: View {
  let smartPaste: SmartPasteController

  @State private var loginItem = LoginItem.state
  @State private var loginItemError: String?
  @AppStorage(SmartPasteController.enabledKey) private var smartPasteEnabled = false
  @AppStorage(SmartPasteController.historySizeKey) private var historySize =
    ClipboardHistory.defaultCapacity
  @State private var accessibilityGranted = SystemAccessibilityPermission().isGranted()

  var body: some View {
    Form {
      Section {
        // The Recorder warns when a shortcut is reserved by macOS or used by a menu.
        KeyboardShortcuts.Recorder("Capture text:", name: .captureText)
        // A Binding rather than onChange: refreshing the state after a failure mustn't call
        // setLaunchAtLogin again (that would undo the change and overwrite the error).
        Toggle(
          "Launch scoop at login",
          isOn: Binding(get: { loginItem.isOn }, set: { setLaunchAtLogin($0) }))
        if let message = loginItemError ?? loginItem.message {
          Text(message).font(.caption).foregroundStyle(.secondary)
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
        }
        if smartPasteEnabled {
          permissionStatus
          KeyboardShortcuts.Recorder("Clipboard history:", name: .smartPasteSwitcher)
          ForEach(KeyboardShortcuts.Name.smartPastePositions, id: \.position) { shortcut in
            KeyboardShortcuts.Recorder(
              "Paste past clipboard \(shortcut.position):", name: shortcut.name)
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
    // Coming back from System Settings (permission granted, login item changed) updates both.
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    { _ in refreshStatus() }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
      _ in refreshStatus()
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

  private func refreshPermission() {
    accessibilityGranted = SystemAccessibilityPermission().isGranted()
  }

  private func refreshStatus() {
    refreshPermission()
    loginItem = LoginItem.state
  }

  private func setLaunchAtLogin(_ enabled: Bool) {
    do {
      try LoginItem.setEnabled(enabled)
      loginItemError = nil
    } catch {
      loginItemError = "Couldn't change the login setting: \(error.localizedDescription)"
    }
    // Show what macOS actually has, whether or not the change worked.
    loginItem = LoginItem.state
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
