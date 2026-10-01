import Testing

@testable import TextGrabCore

@MainActor
private final class FakePermission: ScreenPermission {
  var granted: Bool
  private(set) var requestCount = 0
  init(granted: Bool) { self.granted = granted }
  func isGranted() -> Bool { granted }
  func request() { requestCount += 1 }
}

private actor FakeCapture: CaptureService {
  enum Outcome: Sendable { case image, cancelled, failure }

  private let outcome: Outcome
  private let holdUntilReleased: Bool
  private var gate: CheckedContinuation<Void, Never>?
  private(set) var calls = 0

  init(_ outcome: Outcome, holdUntilReleased: Bool = false) {
    self.outcome = outcome
    self.holdUntilReleased = holdUntilReleased
  }

  func captureSelection() async throws -> CapturedImage? {
    calls += 1
    if holdUntilReleased {
      await withCheckedContinuation { gate = $0 }
    }
    switch outcome {
    case .image: return CapturedImage(cgImage: TextImage.render(["x"]))
    case .cancelled: return nil
    case .failure: throw CaptureError.unreadableImage
    }
  }

  func release() {
    gate?.resume()
    gate = nil
  }
}

private struct FakeRecognizer: TextRecognizer {
  enum Outcome: Sendable {
    case text(String)
    case failure
  }
  struct Failed: Error {}
  var outcome: Outcome

  func recognize(_ image: CapturedImage) async throws -> String {
    switch outcome {
    case .text(let text): return text
    case .failure: throw Failed()
    }
  }
}

@MainActor
private final class FakeClipboard: ClipboardWriter {
  private(set) var written: [String] = []
  func write(_ text: String) { written.append(text) }
}

@MainActor
private final class FakeFeedback: Feedback {
  private(set) var events: [FeedbackEvent] = []
  func show(_ event: FeedbackEvent) { events.append(event) }
}

@MainActor
@Suite struct CaptureCoordinatorTests {
  private let clipboard = FakeClipboard()
  private let feedback = FakeFeedback()

  private func makeCoordinator(
    granted: Bool = true,
    capture: FakeCapture = FakeCapture(.image),
    recognized: FakeRecognizer.Outcome = .text("Hello")
  ) -> (CaptureCoordinator, FakePermission) {
    let permission = FakePermission(granted: granted)
    let coordinator = CaptureCoordinator(
      permission: permission, capture: capture,
      recognizer: FakeRecognizer(outcome: recognized),
      clipboard: clipboard, feedback: feedback)
    return (coordinator, permission)
  }

  @Test func copiesRecognizedTextAndConfirms() async {
    let (coordinator, _) = makeCoordinator(recognized: .text("Hello\nWorld"))
    await coordinator.trigger()
    #expect(clipboard.written == ["Hello\nWorld"])
    #expect(feedback.events == [.copied])
  }

  @Test func cancelDoesNothing() async {
    let (coordinator, _) = makeCoordinator(capture: FakeCapture(.cancelled))
    await coordinator.trigger()
    #expect(clipboard.written.isEmpty)
    #expect(feedback.events.isEmpty)
  }

  @Test func emptyTextIsNoText() async {
    let (coordinator, _) = makeCoordinator(recognized: .text(""))
    await coordinator.trigger()
    #expect(clipboard.written.isEmpty)
    #expect(feedback.events == [.noText])
  }

  @Test func whitespaceOnlyTextIsNoText() async {
    let (coordinator, _) = makeCoordinator(recognized: .text("  \n\t \n"))
    await coordinator.trigger()
    #expect(clipboard.written.isEmpty)
    #expect(feedback.events == [.noText])
  }

  @Test func captureFailureLeavesClipboardAlone() async {
    let (coordinator, _) = makeCoordinator(capture: FakeCapture(.failure))
    await coordinator.trigger()
    #expect(clipboard.written.isEmpty)
    #expect(feedback.events == [.captureFailed])
  }

  @Test func recognitionFailureLeavesClipboardAlone() async {
    let (coordinator, _) = makeCoordinator(recognized: .failure)
    await coordinator.trigger()
    #expect(clipboard.written.isEmpty)
    #expect(feedback.events == [.recognitionFailed])
  }

  @Test func missingPermissionRequestsItAndStops() async {
    let capture = FakeCapture(.image)
    let (coordinator, permission) = makeCoordinator(granted: false, capture: capture)
    await coordinator.trigger()
    #expect(permission.requestCount == 1)
    #expect(feedback.events == [.permissionNeeded])
    #expect(await capture.calls == 0)
    #expect(clipboard.written.isEmpty)
  }

  @Test func secondTriggerWhileCapturingIsIgnored() async {
    let capture = FakeCapture(.image, holdUntilReleased: true)
    let (coordinator, _) = makeCoordinator(capture: capture)

    let first = Task { await coordinator.trigger() }
    while await capture.calls == 0 { await Task.yield() }
    #expect(coordinator.isCapturing)

    await coordinator.trigger()
    #expect(await capture.calls == 1)

    await capture.release()
    await first.value
    #expect(feedback.events == [.copied])
    #expect(!coordinator.isCapturing)
  }

  @Test func canCaptureAgainAfterAFailure() async {
    let capture = FakeCapture(.failure)
    let (coordinator, _) = makeCoordinator(capture: capture)
    await coordinator.trigger()
    await coordinator.trigger()
    #expect(await capture.calls == 2)
    #expect(feedback.events == [.captureFailed, .captureFailed])
  }
}
