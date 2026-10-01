import AppKit
import Testing

@testable import TextGrabCore

@MainActor
@Suite struct PasteboardWriterTests {
  /// A private, uniquely named pasteboard so tests never touch the real clipboard.
  private func makePasteboard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("textgrab-tests-\(UUID().uuidString)"))
  }

  @Test func writesPlainText() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    PasteboardWriter(pasteboardName: pasteboard.name).write("Hello, world")
    #expect(pasteboard.string(forType: .string) == "Hello, world")
  }

  @Test func replacesRichContentWithPlainText() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setData(Data("{\\rtf1 old}".utf8), forType: .rtf)
    pasteboard.setString("<b>old</b>", forType: .html)

    PasteboardWriter(pasteboardName: pasteboard.name).write("new text")

    let types = pasteboard.types ?? []
    #expect(!types.contains(.rtf))
    #expect(!types.contains(.html))
    #expect(pasteboard.string(forType: .string) == "new text")
  }
}
