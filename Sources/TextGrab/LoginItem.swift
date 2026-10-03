import ServiceManagement
import TextGrabCore

/// Launch at login via SMAppService (macOS 13+).
@MainActor
enum LoginItem {
  /// Read fresh each time: the user can change it in System Settings → Login Items.
  static var state: LoginItemState { LoginItemState(status: SMAppService.mainApp.status) }

  static func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }
}
