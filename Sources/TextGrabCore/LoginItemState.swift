import ServiceManagement

/// What the "Launch at login" setting shows for a login item's status.
public struct LoginItemState: Equatable, Sendable {
  public var isOn: Bool
  public var message: String?

  public init(isOn: Bool, message: String?) {
    self.isOn = isOn
    self.message = message
  }

  public init(status: SMAppService.Status) {
    switch status {
    case .enabled:
      self.init(isOn: true, message: nil)
    case .requiresApproval:
      // Registered, but macOS won't start it until the user approves it.
      self.init(
        isOn: true, message: "Approve scoop in System Settings → General → Login Items.")
    default:
      self.init(isOn: false, message: nil)
    }
  }
}
