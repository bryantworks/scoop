import Testing

@testable import TextGrabCore

@Suite struct CaptureSoundTests {
  @Test func aCopyPlaysFrog() {
    #expect(CaptureSound.name(for: .copied, enabled: true, systemSoundsOn: true) == "Frog")
  }

  @Test(arguments: [FeedbackEvent.noText, .captureFailed, .recognitionFailed])
  func aCaptureThatGotNoTextPlaysSosumi(event: FeedbackEvent) {
    #expect(CaptureSound.name(for: event, enabled: true, systemSoundsOn: true) == "Sosumi")
  }

  /// Permission alerts are their own window, and Smart Paste keeps its own beep.
  @Test(arguments: [FeedbackEvent.permissionNeeded, .accessibilityNeeded, .nothingToPaste])
  func otherEventsPlayNothing(event: FeedbackEvent) {
    #expect(CaptureSound.name(for: event, enabled: true, systemSoundsOn: true) == nil)
  }

  @Test(arguments: [(false, true), (true, false), (false, false)])
  func eitherSwitchOffSilencesIt(enabled: Bool, systemSoundsOn: Bool) {
    #expect(
      CaptureSound.name(for: .copied, enabled: enabled, systemSoundsOn: systemSoundsOn) == nil)
    #expect(
      CaptureSound.name(for: .noText, enabled: enabled, systemSoundsOn: systemSoundsOn) == nil)
  }

  /// macOS stores "Play user interface sound effects" as 0 or 1, and leaves it unset until the
  /// person changes it (meaning on).
  @Test(arguments: [(nil, true), (1, true), (0, false)] as [(Int?, Bool)])
  func readsTheMacOSInterfaceSoundsSetting(stored: Int?, expected: Bool) {
    #expect(CaptureSound.systemSoundsOn(storedValue: stored) == expected)
  }
}
