import AppKit
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
  @State private var launchAtLogin = LoginItem.isEnabled
  @State private var loginItemMessage: String?

  var body: some View {
    Form {
      // The Recorder warns when a shortcut is reserved by macOS or used by a menu.
      KeyboardShortcuts.Recorder("Capture text:", name: .captureText)
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
    .formStyle(.grouped)
    .frame(width: 420)
    .fixedSize()
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
  private var window: NSWindow?

  func show() {
    if window == nil {
      let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
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
