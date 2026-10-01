import CoreGraphics

@MainActor
public protocol ScreenPermission {
  func isGranted() -> Bool
  /// Shows the system prompt (first time) and registers the app in System Settings.
  func request()
}

public struct SystemScreenPermission: ScreenPermission {
  public init() {}

  public func isGranted() -> Bool { CGPreflightScreenCaptureAccess() }

  public func request() { _ = CGRequestScreenCaptureAccess() }
}
