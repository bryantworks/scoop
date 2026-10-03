import CoreGraphics
import Foundation
import ImageIO

public enum CaptureError: Error, Equatable {
  /// `message` is what the tool printed to stderr, for the log.
  case toolFailed(exitCode: Int32, message: String)
  case unreadableImage
}

public struct ProcessResult: Equatable, Sendable {
  public var status: Int32
  public var standardError: String

  public init(status: Int32, standardError: String = "") {
    self.status = status
    self.standardError = standardError
  }
}

public protocol CaptureService: Sendable {
  /// Lets the user drag-select part of the screen. Returns nil if they cancelled.
  func captureSelection() async throws -> CapturedImage?
}

public protocol ProcessRunner: Sendable {
  /// Runs the executable to completion and returns its exit status and stderr.
  func run(_ executable: URL, arguments: [String]) async throws -> ProcessResult
}

public struct SystemProcessRunner: ProcessRunner {
  public init() {}

  public func run(_ executable: URL, arguments: [String]) async throws -> ProcessResult {
    try await withCheckedThrowingContinuation { continuation in
      let process = Process()
      let standardError = Pipe()
      process.executableURL = executable
      process.arguments = arguments
      process.standardError = standardError
      process.terminationHandler = { process in
        let data = standardError.fileHandleForReading.readDataToEndOfFile()
        continuation.resume(
          returning: ProcessResult(
            status: process.terminationStatus,
            standardError: String(decoding: data, as: UTF8.self)))
      }
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
    let result = try await runner.run(Self.tool, arguments: ["-i", "-x", file.path])

    let message = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
    let failure = CaptureError.toolFailed(exitCode: result.status, message: message)

    // Esc or a click without a drag leaves no file (or an empty one) and exits 0 with nothing on
    // stderr: a cancel. A real failure also leaves no file, but exits non-zero and says why.
    // (A silent non-zero exit stays a cancel, in case some macOS version exits 1 on Esc.)
    let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
    guard size > 0 else {
      if result.status != 0 && !message.isEmpty { throw failure }
      return nil
    }
    guard result.status == 0 else { throw failure }

    let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, options)
    else { throw CaptureError.unreadableImage }
    return CapturedImage(cgImage: image)
  }
}
