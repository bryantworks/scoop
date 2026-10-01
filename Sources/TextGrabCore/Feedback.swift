public enum FeedbackEvent: Equatable, Sendable {
  case copied
  case noText
  case captureFailed
  case recognitionFailed
  case permissionNeeded
}

@MainActor
public protocol Feedback {
  func show(_ event: FeedbackEvent)
}
