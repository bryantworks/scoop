import CoreGraphics
import Foundation
import Testing

@testable import TextGrabCore

/// Lowercases and collapses runs of spaces within each line; OCR spacing and casing can vary.
private func normalized(_ text: String) -> String {
  text.split(separator: "\n", omittingEmptySubsequences: true)
    .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased() }
    .joined(separator: "\n")
}

// GitHub's macOS runners are virtual machines without the Neural Engine; Vision text
// recognition stalls there (observed: no test finishes within 4 minutes). These tests run
// on real Macs — locally on every `swift test`, and before each release (docs/testing.md).
@Suite(
  .disabled(
    if: ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true",
    "Vision stalls on GitHub's virtualized runners; run on a real Mac"))
struct VisionTextRecognizerTests {
  let recognizer = VisionTextRecognizer()

  private func read(_ image: CGImage) async throws -> String {
    try await recognizer.recognize(CapturedImage(cgImage: image))
  }

  @Test func readsASingleLine() async throws {
    let text = try await read(TextImage.render(["The quick brown fox"]))
    #expect(normalized(text) == "the quick brown fox")
  }

  @Test func keepsLineBreaksBetweenLines() async throws {
    let text = try await read(
      TextImage.render(["First line of text", "Second line here", "Third and final line"]))
    #expect(normalized(text) == "first line of text\nsecond line here\nthird and final line")
  }

  @Test func readsWhiteTextOnADarkBackground() async throws {
    let image = TextImage.render(
      ["Dark mode works"], foreground: .white, background: CGColor(gray: 0.1, alpha: 1))
    #expect(normalized(try await read(image)) == "dark mode works")
  }

  @Test func readsSmallText() async throws {
    // 24 px is 12 pt text on a Retina (2x) screen.
    let text = try await read(TextImage.render(["Small print matters"], fontSize: 24))
    #expect(normalized(text) == "small print matters")
  }

  @Test func keepsAccentedCharacters() async throws {
    let text = try await read(TextImage.render(["Café déjà vu"]))
    #expect(normalized(text) == "café déjà vu")
  }

  @Test func blankImageGivesEmptyText() async throws {
    #expect(try await read(TextImage.render([])) == "")
  }
}
