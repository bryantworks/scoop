import Foundation

/// Hotkey → permission check → selection → recognition → clipboard → feedback.
/// Never overwrites the clipboard on failure; stays silent when the user cancels.
@MainActor
public final class CaptureCoordinator {
  private let permission: any ScreenPermission
  private let capture: any CaptureService
  private let recognizer: any TextRecognizer
  private let clipboard: any ClipboardWriter
  private let feedback: any Feedback
  private let recognitionTimeout: Duration
  private let log = AppInfo.logger("capture")

  public private(set) var isCapturing = false

  public init(
    permission: any ScreenPermission,
    capture: any CaptureService,
    recognizer: any TextRecognizer,
    clipboard: any ClipboardWriter,
    feedback: any Feedback,
    recognitionTimeout: Duration = .seconds(30)
  ) {
    self.permission = permission
    self.capture = capture
    self.recognizer = recognizer
    self.clipboard = clipboard
    self.feedback = feedback
    self.recognitionTimeout = recognitionTimeout
  }

  public func trigger() async {
    guard !isCapturing else { return }
    isCapturing = true
    defer { isCapturing = false }

    guard permission.isGranted() else {
      permission.request()
      feedback.show(.permissionNeeded)
      return
    }

    let image: CapturedImage
    do {
      guard let captured = try await capture.captureSelection() else { return }
      image = captured
    } catch {
      log.error("Capture failed: \(String(describing: error), privacy: .public)")
      feedback.show(.captureFailed)
      return
    }

    // A deadline, so a stalled recognition can't leave isCapturing stuck (which would
    // ignore every later shortcut press until relaunch).
    let text: String
    do {
      text = try await withDeadline(recognitionTimeout) { [recognizer] in
        try await recognizer.recognize(image)
      }
    } catch {
      log.error("Recognition failed: \(String(describing: error), privacy: .public)")
      feedback.show(.recognitionFailed)
      return
    }

    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      feedback.show(.noText)
      return
    }
    clipboard.write(text)
    feedback.show(.copied)
  }
}
