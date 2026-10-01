import Foundation
import Testing

@testable import TextGrabCore

private func item(_ text: String, from app: String? = nil) -> ClipboardItem {
  ClipboardItem(plainText: text, sourceBundleID: app)
}

/// Records each text in order, so the last one ends up as the current clipboard.
private func history(_ texts: [String], capacity: Int = 10) -> ClipboardHistory {
  var history = ClipboardHistory(capacity: capacity)
  for text in texts { history.record(item(text)) }
  return history
}

private func texts(_ history: ClipboardHistory) -> [String?] {
  history.items.map(\.plainText)
}

@Suite struct ClipboardHistoryTests {
  @Test func newestCopyIsTheCurrentClipboard() {
    let history = history(["a", "b", "c"])
    #expect(texts(history) == ["c", "b", "a"])
    #expect(history.item(at: 0)?.plainText == "c")
    #expect(history.item(at: 1)?.plainText == "b")  // past clipboard 1
  }

  @Test func positionsOutsideTheHistoryAreNil() {
    let history = history(["a", "b"])
    #expect(history.item(at: 2) == nil)
    #expect(history.item(at: -1) == nil)
  }

  @Test func defaultCapacityIsTen() {
    let history = history((1...15).map(String.init), capacity: ClipboardHistory.defaultCapacity)
    #expect(ClipboardHistory.defaultCapacity == 10)
    #expect(history.items.count == 10)
    #expect(history.item(at: 0)?.plainText == "15")
    #expect(history.item(at: 9)?.plainText == "6")
  }

  @Test func promoteMovesTheItemToTheTopWithExactlyOneShift() {
    var history = history(["a", "b", "c", "d", "e"])  // e d c b a
    let pasted = history.promote(position: 3)
    #expect(pasted?.plainText == "b")
    // Only the items above the promoted one move back; nothing is duplicated or lost.
    #expect(texts(history) == ["b", "e", "d", "c", "a"])
  }

  @Test func promotingTheCurrentClipboardChangesNothing() {
    var history = history(["a", "b"])
    let pasted = history.promote(position: 0)
    #expect(pasted?.plainText == "b")
    #expect(texts(history) == ["b", "a"])
  }

  @Test func promotingAnEmptyPositionChangesNothing() {
    var history = history(["a", "b"])
    let pasted = history.promote(position: 5)
    #expect(pasted == nil)
    #expect(texts(history) == ["b", "a"])
  }

  @Test func repeatedPromotesOfPositionFivePasteTheLastSixInCopyOrder() {
    var history = history(["one", "two", "three", "four", "five", "six"])
    let pasted = (1...6).map { _ in history.promote(position: 5)?.plainText }
    #expect(pasted == ["one", "two", "three", "four", "five", "six"])
    #expect(texts(history) == ["six", "five", "four", "three", "two", "one"])
  }

  @Test func repeatedPromotesWorkForEveryFixedPosition() {
    for position in 1...5 {
      let copied = (0...position).map { "item \($0)" }
      var history = history(copied)
      let pasted = copied.map { _ in history.promote(position: position)?.plainText }
      #expect(pasted == copied, "position \(position)")
    }
  }

  @Test func concealedItemsAreSkipped() {
    var history = history(["a"])
    let recorded = history.record(
      item("hunter2"), pasteboardTypes: ["public.utf8-plain-text", ClipboardHistory.concealedType])
    #expect(!recorded)
    #expect(texts(history) == ["a"])
  }

  @Test func transientItemsAreSkipped() {
    var history = history(["a"])
    let recorded = history.record(
      item("temp"), pasteboardTypes: ["public.utf8-plain-text", ClipboardHistory.transientType])
    #expect(!recorded)
    #expect(texts(history) == ["a"])
  }

  @Test func itemsWithoutTextAreSkipped() {
    var history = history(["a"])
    let recorded = history.record(ClipboardItem(representations: [:]))
    #expect(!recorded)
    #expect(texts(history) == ["a"])
  }

  @Test func richTextOnlyItemsAreKept() {
    var history = ClipboardHistory()
    let rtf = ClipboardItem(representations: [ClipboardItem.rtfType: Data("{\\rtf1 hi}".utf8)])
    let recorded = history.record(rtf)
    #expect(recorded)
    #expect(history.items.count == 1)
  }

  @Test func copyingSomethingAlreadyInHistoryMovesItToTheTop() {
    var history = history(["a", "b", "c"])
    history.record(item("a", from: "com.apple.Safari"))
    #expect(texts(history) == ["a", "c", "b"])
    #expect(history.item(at: 0)?.sourceBundleID == "com.apple.Safari")
  }

  @Test func sameTextWithDifferentFormattingIsADifferentItem() {
    var history = history(["a"])
    history.record(
      ClipboardItem(representations: [
        ClipboardItem.plainTextType: Data("a".utf8),
        ClipboardItem.rtfType: Data("{\\rtf1 \\b a}".utf8),
      ]))
    #expect(history.items.count == 2)
  }

  @Test func recordsTheSourceApp() {
    var history = ClipboardHistory()
    history.record(
      ClipboardItem(plainText: "x", sourceBundleID: "com.apple.Notes", sourceAppName: "Notes"))
    #expect(history.item(at: 0)?.sourceBundleID == "com.apple.Notes")
    #expect(history.item(at: 0)?.sourceAppName == "Notes")
  }

  @Test func shrinkingCapacityDropsTheOldestItems() {
    var history = history(["a", "b", "c", "d"])
    history.capacity = 2
    #expect(texts(history) == ["d", "c"])
  }

  @Test func capacityIsAtLeastOne() {
    var history = history(["a", "b"])
    history.capacity = 0
    #expect(history.capacity == 1)
    #expect(texts(history) == ["b"])
  }

  @Test func clearEmptiesTheHistory() {
    var history = history(["a", "b"])
    history.clear()
    #expect(history.items.isEmpty)
  }

  @Test func plainTextIsReadFromTheRepresentation() {
    let item = ClipboardItem(representations: [ClipboardItem.plainTextType: Data("héllo".utf8)])
    #expect(item.plainText == "héllo")
  }

  @Test func imagesAreKeptAndPromotedLikeText() {
    var history = history(["a"])
    let screenshot = ClipboardItem(representations: [ClipboardItem.pngType: Data([1, 2, 3])])
    history.record(screenshot)
    history.record(item("b"))
    let pasted = history.promote(position: 1)
    #expect(pasted?.imageData == Data([1, 2, 3]))
    #expect(pasted?.plainText == nil)
    #expect(history.items.count == 3)
  }

  @Test func itemsOverTheSizeLimitAreSkipped() {
    var history = ClipboardHistory(capacity: 10, maxItemBytes: 100)
    let big = ClipboardItem(representations: [ClipboardItem.pngType: Data(count: 101)])
    let fits = ClipboardItem(representations: [ClipboardItem.pngType: Data(count: 100)])
    let bigRecorded = history.record(big)
    let fitsRecorded = history.record(fits)
    #expect(!bigRecorded)
    #expect(fitsRecorded)
    #expect(history.items.count == 1)
  }

  @Test func theDefaultSizeLimitIsTwentyFiveMegabytes() {
    #expect(ClipboardHistory.defaultMaxItemBytes == 25 * 1024 * 1024)
  }

  @Test func theSameImageCopiedTwiceIsOneEntry() {
    var history = ClipboardHistory()
    history.record(ClipboardItem(representations: [ClipboardItem.pngType: Data([9])]))
    history.record(item("text"))
    history.record(ClipboardItem(representations: [ClipboardItem.pngType: Data([9])]))
    #expect(history.items.count == 2)
    #expect(history.item(at: 0)?.imageData == Data([9]))
  }
}
