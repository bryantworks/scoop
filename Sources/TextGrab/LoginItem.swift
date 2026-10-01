import ServiceManagement

/// Launch at login via SMAppService (macOS 13+).
@MainActor
enum LoginItem {
  static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

  static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

  static func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }
}
