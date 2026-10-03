import ServiceManagement
import Testing

@testable import TextGrabCore

@Suite struct LoginItemStateTests {
  @Test func enabledIsOnWithNoMessage() {
    #expect(LoginItemState(status: .enabled) == LoginItemState(isOn: true, message: nil))
  }

  /// Registered but waiting for approval: the toggle stays on, and the user is told what to do.
  @Test func requiresApprovalIsOnAndAsksForApproval() {
    let state = LoginItemState(status: .requiresApproval)
    #expect(state.isOn)
    #expect(state.message == "Approve scoop in System Settings → General → Login Items.")
  }

  @Test(arguments: [SMAppService.Status.notRegistered, .notFound])
  func otherStatusesAreOff(_ status: SMAppService.Status) {
    #expect(LoginItemState(status: status) == LoginItemState(isOn: false, message: nil))
  }
}
