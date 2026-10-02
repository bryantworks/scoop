import Foundation
import Testing

@testable import TextGrabCore

/// Stands in for /usr/sbin/screencapture: writes (or doesn't write) the output file, then exits.
/// Internal (not private) because it's used as a parameterized-test argument.
struct FakeRunner: ProcessRunner {
  enum Behavior: Sendable, CaseIterable {
    case writePNG, writeEmptyFile, writeNothing, writeGarbage
  }

  var behavior: Behavior
  var exitCode: Int32 = 0

  func run(_ executable: URL, arguments: [String]) async throws -> Int32 {
    #expect(executable.path == "/usr/sbin/screencapture")
    #expect(Array(arguments.prefix(2)) == ["-i", "-x"])
    let output = URL(filePath: arguments.last!)
    switch behavior {
    case .writePNG:
      try TextImage.pngData(TextImage.render(["hello"])).write(to: output)
    case .writeEmptyFile:
      try Data().write(to: output)
    case .writeNothing:
      break
    case .writeGarbage:
      try Data("not an image".utf8).write(to: output)
    }
    return exitCode
  }
}

private struct ThrowingRunner: ProcessRunner {
  struct LaunchFailed: Error {}
  func run(_ executable: URL, arguments: [String]) async throws -> Int32 { throw LaunchFailed() }
}

private func contents(of directory: URL) throws -> [String] {
  try FileManager.default.contentsOfDirectory(atPath: directory.path)
}

/// A class so `deinit` can delete each test's temporary folder (Swift Testing makes a new
/// instance for every test).
@Suite final class ScreencaptureServiceTests {
  private let dir: URL

  init() throws {
    dir = FileManager.default.temporaryDirectory
      .appending(path: "textgrab-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  }

  deinit {
    try? FileManager.default.removeItem(at: dir)
  }

  @Test func returnsImageWhenSelectionIsSaved() async throws {
    let service = ScreencaptureService(
      runner: FakeRunner(behavior: .writePNG), temporaryDirectory: dir)
    let image = try await service.captureSelection()
    #expect(image != nil)
    #expect(image?.cgImage.width == 1200)
  }

  @Test func returnsNilWhenUserCancels() async throws {
    // screencapture exits non-zero and writes nothing when Esc is pressed.
    let service = ScreencaptureService(
      runner: FakeRunner(behavior: .writeNothing, exitCode: 1), temporaryDirectory: dir)
    #expect(try await service.captureSelection() == nil)
  }

  @Test func returnsNilWhenFileIsEmpty() async throws {
    // A click without a drag can leave a zero-byte file: treat as cancel, not an error.
    let service = ScreencaptureService(
      runner: FakeRunner(behavior: .writeEmptyFile), temporaryDirectory: dir)
    #expect(try await service.captureSelection() == nil)
  }

  @Test func throwsToolFailedWhenExitCodeIsNonZeroButFileWasWritten() async throws {
    let service = ScreencaptureService(
      runner: FakeRunner(behavior: .writePNG, exitCode: 2), temporaryDirectory: dir)
    await #expect(throws: CaptureError.toolFailed(exitCode: 2)) {
      try await service.captureSelection()
    }
  }

  @Test func throwsUnreadableImageForGarbage() async throws {
    let service = ScreencaptureService(
      runner: FakeRunner(behavior: .writeGarbage), temporaryDirectory: dir)
    await #expect(throws: CaptureError.unreadableImage) {
      try await service.captureSelection()
    }
  }

  @Test func propagatesLaunchFailure() async throws {
    let service = ScreencaptureService(runner: ThrowingRunner(), temporaryDirectory: dir)
    await #expect(throws: ThrowingRunner.LaunchFailed.self) {
      try await service.captureSelection()
    }
  }

  @Test(arguments: FakeRunner.Behavior.allCases)
  func neverLeavesTheScreenshotBehind(_ behavior: FakeRunner.Behavior) async throws {
    let service = ScreencaptureService(
      runner: FakeRunner(behavior: behavior), temporaryDirectory: dir)
    _ = try? await service.captureSelection()
    #expect(try contents(of: dir).isEmpty)
  }
}
