import Testing

@testable import TextGrabCore

/// A pasteboard plus a log of everything that happened, in order.
@MainActor
private final class Recorder {
  var log: [String] = []
}

@MainActor
private final class FakePasteboard: PasteboardAccess {
  private let recorder: Recorder
  private(set) var changeCount = 0
  private var current: PasteboardSnapshot?
  private(set) var writes: [String?] = []
  /// Like the real pasteboard, reads are attributed to whichever app is frontmost.
  var frontmostApp: String?

  init(recorder: Recorder) { self.recorder = recorder }

  /// Another app copies something.
  func copy(_ text: String, from app: String? = nil, extraTypes: [String] = []) {
    changeCount += 1
    frontmostApp = app
    current = PasteboardSnapshot(
      item: ClipboardItem(plainText: text, sourceBundleID: app),
      types: [ClipboardItem.plainTextType] + extraTypes)
  }

  var currentText: String? { current?.item.plainText }

  func readSnapshot() -> PasteboardSnapshot? {
    guard var snapshot = current else { return nil }
    snapshot.item.sourceBundleID = frontmostApp
    return snapshot
  }

  func write(_ item: ClipboardItem) -> Int {
    changeCount += 1
    current = PasteboardSnapshot(item: item, types: Array(item.representations.keys))
    writes.append(item.plainText)
    recorder.log.append("write \(item.plainText ?? "?")")
    return changeCount
  }
}

@MainActor
private final class FakeKeystrokes: KeystrokeSender {
  private let recorder: Recorder
  private let pasteboard: FakePasteboard
  /// What the target app received, one entry per ⌘V.
  private(set) var pasted: [String?] = []

  init(recorder: Recorder, pasteboard: FakePasteboard) {
    self.recorder = recorder
    self.pasteboard = pasteboard
  }

  func sendPaste() {
    pasted.append(pasteboard.currentText)
    recorder.log.append("⌘V")
  }
}

@MainActor
private final class FakeAccessibility: AccessibilityPermission {
  var granted: Bool
  private(set) var requestCount = 0
  init(granted: Bool) { self.granted = granted }
  func isGranted() -> Bool { granted }
  func request() { requestCount += 1 }
}

@MainActor
private final class FakeFeedback: Feedback {
  private(set) var events: [FeedbackEvent] = []
  func show(_ event: FeedbackEvent) { events.append(event) }
}

@MainActor
private struct Harness {
  let recorder = Recorder()
  let pasteboard: FakePasteboard
  let keystrokes: FakeKeystrokes
  let permission: FakeAccessibility
  let feedback = FakeFeedback()
  let coordinator: SmartPasteCoordinator

  /// `copies` happen (oldest first) before Smart Paste starts watching; the newest one is the
  /// current clipboard when it starts.
  init(
    copies: [String] = [], granted: Bool = true,
    settle: (@MainActor (Recorder) async -> Void)? = nil
  ) {
    pasteboard = FakePasteboard(recorder: recorder)
    keystrokes = FakeKeystrokes(recorder: recorder, pasteboard: pasteboard)
    permission = FakeAccessibility(granted: granted)
    let recorder = recorder
    coordinator = SmartPasteCoordinator(
      pasteboard: pasteboard, keystrokes: keystrokes, permission: permission,
      feedback: feedback,
      settle: {
        if let settle {
          await settle(recorder)
        } else {
          recorder.log.append("settle")
        }
      })
    for text in copies {
      pasteboard.copy(text)
      coordinator.tick()
    }
  }

  var history: [String?] { coordinator.history.items.map(\.plainText) }

  /// A real key press: down then up.
  func press(_ position: Int) {
    coordinator.keyDown(position: position)
    coordinator.keyUp(position: position)
  }
}

@MainActor
@Suite struct SmartPasteCoordinatorTests {
  @Test func theCurrentClipboardIsTheFirstItem() {
    let harness = Harness()
    harness.pasteboard.copy("already there")
    let coordinator = SmartPasteCoordinator(
      pasteboard: harness.pasteboard, keystrokes: harness.keystrokes,
      permission: harness.permission, feedback: harness.feedback, settle: {})
    #expect(coordinator.history.items.map(\.plainText) == ["already there"])
  }

  @Test func aCopyInAnotherAppIsRecordedWithItsSourceApp() {
    let harness = Harness(copies: ["a"])
    harness.pasteboard.copy("b", from: "com.apple.Safari")
    harness.coordinator.tick()
    #expect(harness.history == ["b", "a"])
    #expect(harness.coordinator.history.item(at: 0)?.sourceBundleID == "com.apple.Safari")
  }

  @Test func pollingWithoutAChangeRecordsNothing() {
    let harness = Harness(copies: ["a"])
    harness.coordinator.tick()
    harness.coordinator.tick()
    #expect(harness.history == ["a"])
  }

  @Test func concealedCopiesAreNotRecorded() {
    let harness = Harness(copies: ["a"])
    harness.pasteboard.copy("hunter2", extraTypes: [ClipboardHistory.concealedType])
    harness.coordinator.tick()
    #expect(harness.history == ["a"])
  }

  @Test func pastingSetsTheClipboardThenPressesCommandV() async {
    let harness = Harness(copies: ["a", "b", "c"])
    harness.press(2)
    await harness.coordinator.waitUntilIdle()
    #expect(harness.recorder.log == ["write a", "⌘V", "settle"])
    #expect(harness.keystrokes.pasted == ["a"])
  }

  @Test func aPasteShiftsTheHistoryExactlyOnce() async {
    let harness = Harness(copies: ["a", "b", "c", "d"])  // d c b a
    harness.press(2)
    await harness.coordinator.waitUntilIdle()
    // Our own clipboard write is seen by the next poll, but isn't recorded as a new copy.
    harness.coordinator.tick()
    harness.coordinator.tick()
    #expect(harness.history == ["b", "d", "c", "a"])
  }

  @Test func aPastedItemKeepsTheAppItWasCopiedFrom() async {
    let harness = Harness()
    harness.pasteboard.copy("a", from: "com.apple.Safari")
    harness.coordinator.tick()
    harness.pasteboard.copy("b", from: "com.apple.Notes")
    harness.coordinator.tick()
    harness.pasteboard.frontmostApp = "com.apple.TextEdit"  // pasting into TextEdit
    harness.press(1)
    await harness.coordinator.waitUntilIdle()
    harness.coordinator.tick()
    #expect(harness.history == ["a", "b"])
    #expect(harness.coordinator.history.item(at: 0)?.sourceBundleID == "com.apple.Safari")
  }

  @Test func repeatingTheLastPositionPastesTheLastSixInCopyOrder() async {
    let harness = Harness(copies: ["one", "two", "three", "four", "five", "six"])
    for _ in 1...6 {
      harness.press(5)
      harness.coordinator.tick()  // polls in between presses change nothing
    }
    await harness.coordinator.waitUntilIdle()
    #expect(harness.keystrokes.pasted == ["one", "two", "three", "four", "five", "six"])
    #expect(harness.history == ["six", "five", "four", "three", "two", "one"])
  }

  @Test func autoRepeatWhileTheKeyIsHeldPastesOnce() async {
    let harness = Harness(copies: ["a", "b", "c"])
    harness.coordinator.keyDown(position: 1)
    harness.coordinator.keyDown(position: 1)  // auto-repeat
    harness.coordinator.keyDown(position: 1)
    await harness.coordinator.waitUntilIdle()
    #expect(harness.keystrokes.pasted == ["b"])

    harness.coordinator.keyUp(position: 1)
    harness.coordinator.keyDown(position: 1)  // a real second press
    await harness.coordinator.waitUntilIdle()
    #expect(harness.keystrokes.pasted == ["b", "c"])
  }

  @Test func pressesDuringAPasteWaitForItToFinish() async {
    // Three more presses arrive while the first paste is still settling.
    var pressedDuringSettle = false
    var harness: Harness!
    harness = Harness(
      copies: ["one", "two", "three", "four", "five", "six"],
      settle: { recorder in
        recorder.log.append("settle start")
        if !pressedDuringSettle {
          pressedDuringSettle = true
          for _ in 1...3 { harness.press(5) }
        }
        await Task.yield()
        recorder.log.append("settle end")
      })
    harness.press(5)
    await harness.coordinator.waitUntilIdle()

    let onePaste = ["⌘V", "settle start", "settle end"]
    #expect(
      harness.recorder.log
        == ["write one"] + onePaste + ["write two"] + onePaste + ["write three"] + onePaste
        + ["write four"] + onePaste)
    #expect(harness.keystrokes.pasted == ["one", "two", "three", "four"])
  }

  @Test func differentPositionsInQuickSuccessionRunInOrder() async {
    let harness = Harness(copies: ["a", "b", "c", "d"])  // d c b a
    harness.press(3)  // a → a d c b
    harness.press(1)  // d → d a c b
    harness.press(3)  // b → b d a c
    await harness.coordinator.waitUntilIdle()
    #expect(harness.keystrokes.pasted == ["a", "d", "b"])
    #expect(harness.history == ["b", "d", "a", "c"])
  }

  @Test func aCopyMadeJustBeforeAPressCountsEvenBeforeThePollSeesIt() async {
    let harness = Harness(copies: ["a", "b"])
    harness.pasteboard.copy("c")  // no tick yet
    harness.press(1)
    await harness.coordinator.waitUntilIdle()
    #expect(harness.keystrokes.pasted == ["b"])
    #expect(harness.history == ["b", "c", "a"])
  }

  @Test func scoopsOwnCapturesAreRecordedLikeAnyCopy() {
    // OCR writes go straight to the pasteboard, not through the coordinator.
    let harness = Harness(copies: ["a"])
    harness.pasteboard.copy("captured text")
    harness.coordinator.tick()
    #expect(harness.history == ["captured text", "a"])
  }

  @Test func anEmptyPositionBeepsAndLeavesTheClipboardAlone() async {
    let harness = Harness(copies: ["a", "b"])
    harness.press(4)
    await harness.coordinator.waitUntilIdle()
    #expect(harness.pasteboard.writes.isEmpty)
    #expect(harness.keystrokes.pasted.isEmpty)
    #expect(harness.feedback.events == [.nothingToPaste])
  }

  @Test func withoutPermissionNothingIsPastedAndItExplainsOnce() async {
    let harness = Harness(copies: ["a", "b", "c"], granted: false)
    harness.press(1)
    harness.press(1)
    harness.press(2)
    await harness.coordinator.waitUntilIdle()
    #expect(harness.pasteboard.writes.isEmpty)
    #expect(harness.keystrokes.pasted.isEmpty)
    #expect(harness.feedback.events == [.accessibilityNeeded])
    #expect(harness.history == ["c", "b", "a"])
  }

  @Test func pastingWorksOnceThePermissionIsGranted() async {
    let harness = Harness(copies: ["a", "b"], granted: false)
    harness.press(1)
    await harness.coordinator.waitUntilIdle()
    harness.permission.granted = true
    harness.press(1)
    await harness.coordinator.waitUntilIdle()
    #expect(harness.keystrokes.pasted == ["a"])
  }

  @Test func requestsPermissionOnlyWhenMissing() {
    let missing = Harness(granted: false)
    missing.coordinator.requestPermissionIfNeeded()
    #expect(missing.permission.requestCount == 1)

    let granted = Harness(granted: true)
    granted.coordinator.requestPermissionIfNeeded()
    #expect(granted.permission.requestCount == 0)
  }
}
