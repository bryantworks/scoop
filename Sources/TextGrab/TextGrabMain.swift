import KeyboardShortcuts
import SwiftUI
import TextGrabCore

// Toolchain check (spec risk 5): proves KeyboardShortcuts, including its SwiftUI Recorder,
// builds with only the command line tools. Replaced by the real entry point in Task 2.
@main
@MainActor
enum TextGrabMain {
  static func main() {
    _ = KeyboardShortcuts.Recorder("Capture text:", name: .init("toolchainCheck"))
    print(AppInfo.bundleIdentifier)
  }
}
