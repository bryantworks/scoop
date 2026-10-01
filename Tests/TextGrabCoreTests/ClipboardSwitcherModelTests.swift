import Foundation
import Testing

@testable import TextGrabCore

private func items(_ texts: [String]) -> [ClipboardItem] {
  texts.map { ClipboardItem(plainText: $0) }
}

@Suite struct ClipboardSearchTests {
  @Test func anEmptyQueryKeepsEverythingWithItsPosition() {
    let results = ClipboardSearch.filter(items(["a", "b", "c"]), query: "  ")
    #expect(results.map(\.position) == [0, 1, 2])
  }

  @Test func matchesKeepTheirOriginalPositionNumbers() {
    let results = ClipboardSearch.filter(
      items(["apple pie", "banana", "Pineapple", "cherry"]), query: "apple")
    #expect(results.map(\.position) == [0, 2])
    #expect(results.map(\.item.plainText) == ["apple pie", "Pineapple"])
  }

  @Test func matchingIgnoresCaseAndAccents() {
    let results = ClipboardSearch.filter(items(["Café Menu", "cafeteria"]), query: "CAFE")
    #expect(results.map(\.position) == [0, 1])
  }

  @Test func matchingTreatsAnyRunOfWhitespaceAsOneSpace() {
    let results = ClipboardSearch.filter(
      items(["first\n\n  second", "other"]), query: "first second")
    #expect(results.map(\.position) == [0])
  }

  @Test func itemsWithoutPlainTextNeverMatchAQuery() {
    let rtfOnly = ClipboardItem(representations: [ClipboardItem.rtfType: Data("{\\rtf1 x}".utf8)])
    #expect(ClipboardSearch.filter([rtfOnly], query: "x").isEmpty)
    #expect(ClipboardSearch.filter([rtfOnly], query: "").count == 1)
  }

  @Test func previewIsOneTidyLine() {
    let item = ClipboardItem(plainText: "  Dear team,\n\n\tThe   report\r\nis ready.  ")
    #expect(ClipboardSearch.preview(item) == "Dear team, The report is ready.")
  }

  @Test func longPreviewsAreTruncatedWithAnEllipsis() {
    let item = ClipboardItem(plainText: String(repeating: "x", count: 500))
    let preview = ClipboardSearch.preview(item, maxLength: 10)
    #expect(preview == String(repeating: "x", count: 10) + "…")
  }

  @Test func previewOfFormattedTextWithoutPlainTextSaysSo() {
    let rtfOnly = ClipboardItem(representations: [ClipboardItem.rtfType: Data("{\\rtf1 x}".utf8)])
    #expect(ClipboardSearch.preview(rtfOnly) == "Formatted text")
  }

  @Test func previewOfWhitespaceOnlyTextSaysSo() {
    #expect(ClipboardSearch.preview(ClipboardItem(plainText: " \n\t")) == "Blank text")
  }
}

@Suite struct ClipboardSwitcherModelTests {
  @Test func opensOnPastClipboardOneLikeCommandTab() {
    // The current clipboard is one ⌘V away already, so the likely pick is the one before it.
    let model = ClipboardSwitcherModel(items: items(["now", "before", "older"]))
    #expect(model.selectedPosition == 1)
  }

  @Test func withOneItemThatItemIsSelected() {
    let model = ClipboardSwitcherModel(items: items(["only"]))
    #expect(model.selectedPosition == 0)
  }

  @Test func anEmptyHistoryHasNoSelection() {
    let model = ClipboardSwitcherModel(items: [])
    #expect(model.results.isEmpty)
    #expect(model.selectedPosition == nil)
  }

  @Test func arrowKeysMoveTheSelectionAndStopAtTheEnds() {
    var model = ClipboardSwitcherModel(items: items(["a", "b", "c"]))
    model.moveSelection(by: 1)
    #expect(model.selectedPosition == 2)
    model.moveSelection(by: 1)
    #expect(model.selectedPosition == 2)
    model.moveSelection(by: -1)
    model.moveSelection(by: -1)
    model.moveSelection(by: -1)
    #expect(model.selectedPosition == 0)
  }

  @Test func typingSelectsTheFirstMatch() {
    var model = ClipboardSwitcherModel(items: items(["apple", "banana", "blueberry"]))
    model.query = "b"
    #expect(model.results.map(\.position) == [1, 2])
    #expect(model.selectedPosition == 1)
    model.moveSelection(by: 1)
    #expect(model.selectedPosition == 2)
  }

  @Test func clearingTheQueryGoesBackToTheDefaultSelection() {
    var model = ClipboardSwitcherModel(items: items(["apple", "banana", "blueberry"]))
    model.query = "blue"
    model.query = ""
    #expect(model.selectedPosition == 1)
  }

  @Test func noMatchesMeansNothingToPaste() {
    var model = ClipboardSwitcherModel(items: items(["apple"]))
    model.query = "zzz"
    #expect(model.selectedPosition == nil)
    model.moveSelection(by: 1)
    #expect(model.selectedPosition == nil)
  }

  @Test func clickingARowSelectsIt() {
    var model = ClipboardSwitcherModel(items: items(["a", "b", "c"]))
    model.select(position: 2)
    #expect(model.selectedPosition == 2)
    model.select(position: 7)  // not in the results: ignored
    #expect(model.selectedPosition == 2)
  }
}
