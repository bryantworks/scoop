public enum FeedbackEvent: Equatable, Sendable {
  case copied
  case noText
  case captureFailed
  case recognitionFailed
  case permissionNeeded
  /// Smart Paste can't simulate ⌘V without Accessibility permission.
  case accessibilityNeeded
  /// Smart Paste was asked for a history position that's empty.
  case nothingToPaste
}

@MainActor
public protocol Feedback {
  func show(_ event: FeedbackEvent)
}
