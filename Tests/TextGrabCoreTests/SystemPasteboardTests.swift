import AppKit
import Testing

@testable import TextGrabCore

@MainActor
@Suite struct SystemPasteboardTests {
  /// A private, uniquely named pasteboard so tests never touch the real clipboard.
  private func makePasteboard() -> NSPasteboard {
    NSPasteboard(name: NSPasteboard.Name("textgrab-tests-\(UUID().uuidString)"))
  }

  private func access(_ pasteboard: NSPasteboard) -> SystemPasteboard {
    SystemPasteboard(
      pasteboardName: pasteboard.name,
      sourceApp: { .init(bundleID: "com.apple.Notes", name: "Notes") })
  }

  @Test func readsPlainAndRichTextWithTheSourceApp() throws {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("hello", forType: .string)
    pasteboard.setData(Data("{\\rtf1 hello}".utf8), forType: .rtf)

    let snapshot = try #require(access(pasteboard).readSnapshot())
    #expect(snapshot.item.plainText == "hello")
    #expect(snapshot.item.representations[ClipboardItem.rtfType] == Data("{\\rtf1 hello}".utf8))
    #expect(snapshot.item.sourceBundleID == "com.apple.Notes")
    #expect(snapshot.item.sourceAppName == "Notes")
  }

  @Test func ignoresUnsupportedTypes() throws {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setData(Data("%PDF".utf8), forType: .pdf)

    let snapshot = try #require(access(pasteboard).readSnapshot())
    #expect(snapshot.item.representations.isEmpty)
    var history = ClipboardHistory()
    let recorded = history.record(snapshot.item, pasteboardTypes: snapshot.types)
    #expect(!recorded)
  }

  @Test func doesNotReadConcealedData() throws {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("hunter2", forType: .string)
    pasteboard.setData(Data(), forType: .init(ClipboardHistory.concealedType))

    let snapshot = try #require(access(pasteboard).readSnapshot())
    #expect(snapshot.item.representations.isEmpty)
    #expect(snapshot.types.contains(ClipboardHistory.concealedType))
  }

  @Test func emptyPasteboardHasNoSnapshot() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    #expect(access(pasteboard).readSnapshot() == nil)
  }

  @Test func writeRestoresEveryRepresentationAndReturnsTheNewChangeCount() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("old", forType: .string)
    let before = pasteboard.changeCount

    let item = ClipboardItem(representations: [
      ClipboardItem.plainTextType: Data("bold".utf8),
      ClipboardItem.rtfType: Data("{\\rtf1 \\b bold}".utf8),
    ])
    let changeCount = access(pasteboard).write(item)

    #expect(changeCount == pasteboard.changeCount)
    #expect(changeCount > before)
    #expect(pasteboard.string(forType: .string) == "bold")
    #expect(pasteboard.data(forType: .rtf) == Data("{\\rtf1 \\b bold}".utf8))
  }

  @Test func readsAnImageOnlyCopy() throws {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setData(Data([0x89, 0x50, 0x4E, 0x47]), forType: .png)

    let snapshot = try #require(access(pasteboard).readSnapshot())
    #expect(
      snapshot.item.representations == [ClipboardItem.pngType: Data([0x89, 0x50, 0x4E, 0x47])])
    #expect(snapshot.item.imageData == Data([0x89, 0x50, 0x4E, 0x47]))
  }

  @Test func keepsOnlyThePreferredImageFormat() throws {
    // Screenshots and browsers often offer the same picture as both PNG and (much larger) TIFF.
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setData(Data([1]), forType: .tiff)
    pasteboard.setData(Data([2]), forType: .png)

    let snapshot = try #require(access(pasteboard).readSnapshot())
    #expect(Array(snapshot.item.representations.keys) == [ClipboardItem.pngType])
  }

  @Test func keepsATiffOnlyImage() throws {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setData(Data([1]), forType: .tiff)

    let snapshot = try #require(access(pasteboard).readSnapshot())
    #expect(snapshot.item.representations == [ClipboardItem.tiffType: Data([1])])
  }

  @Test func skipsTheImagePreviewOfATextCopy() throws {
    // Excel, Word and others attach a picture of the copied text.
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    pasteboard.clearContents()
    pasteboard.setString("A1 B1", forType: .string)
    pasteboard.setData(Data([2]), forType: .png)

    let snapshot = try #require(access(pasteboard).readSnapshot())
    #expect(Array(snapshot.item.representations.keys) == [ClipboardItem.plainTextType])
  }

  @Test func writeRestoresAnImage() {
    let pasteboard = makePasteboard()
    defer { pasteboard.releaseGlobally() }
    let item = ClipboardItem(representations: [ClipboardItem.pngType: Data([0x89, 0x50])])
    _ = access(pasteboard).write(item)
    #expect(pasteboard.data(forType: .png) == Data([0x89, 0x50]))
  }
}
