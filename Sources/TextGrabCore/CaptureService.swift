import CoreGraphics
import Foundation
import ImageIO

public enum CaptureError: Error, Equatable {
  case toolFailed(exitCode: Int32)
  case unreadableImage
}

public protocol CaptureService: Sendable {
  /// Lets the user drag-select part of the screen. Returns nil if they cancelled.
  func captureSelection() async throws -> CapturedImage?
}

public protocol ProcessRunner: Sendable {
  /// Runs the executable to completion and returns its exit status.
  func run(_ executable: URL, arguments: [String]) async throws -> Int32
}

public struct SystemProcessRunner: ProcessRunner {
  public init() {}

  public func run(_ executable: URL, arguments: [String]) async throws -> Int32 {
    try await withCheckedThrowingContinuation { continuation in
      let process = Process()
      process.executableURL = executable
      process.arguments = arguments
      process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
      do {
        try process.run()
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}

/// Captures with macOS's built-in selector (`screencapture -i`, the ⌘⇧4 crosshair).
public struct ScreencaptureService: CaptureService {
  static let tool = URL(filePath: "/usr/sbin/screencapture")

  private let runner: any ProcessRunner
  private let temporaryDirectory: URL

  public init(
    runner: any ProcessRunner = SystemProcessRunner(),
    temporaryDirectory: URL = FileManager.default.temporaryDirectory
  ) {
    self.runner = runner
    self.temporaryDirectory = temporaryDirectory
  }

  public func captureSelection() async throws -> CapturedImage? {
    let file = temporaryDirectory.appending(path: "textgrab-\(UUID().uuidString).png")
    defer { try? FileManager.default.removeItem(at: file) }

    // -i: interactive selection, -x: no shutter sound.
    let status = try await runner.run(Self.tool, arguments: ["-i", "-x", file.path])

    // Esc or a click without a drag leaves no file (or an empty one): a cancel, not an error.
    let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
    guard size > 0 else { return nil }
    guard status == 0 else { throw CaptureError.toolFailed(exitCode: status) }

    let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, options)
    else { throw CaptureError.unreadableImage }
    return CapturedImage(cgImage: image)
  }
}
