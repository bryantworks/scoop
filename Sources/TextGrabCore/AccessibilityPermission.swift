import ApplicationServices

/// Needed to simulate ⌘V for Smart Paste.
@MainActor
public protocol AccessibilityPermission {
  func isGranted() -> Bool
  /// Shows the system prompt (if not yet granted) and registers the app in System Settings.
  func request()
}

public struct SystemAccessibilityPermission: AccessibilityPermission {
  public init() {}

  public func isGranted() -> Bool { AXIsProcessTrusted() }

  public func request() {
    // The value of `kAXTrustedCheckOptionPrompt`, spelled out because that global isn't
    // concurrency-safe under Swift 6.
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }
}
