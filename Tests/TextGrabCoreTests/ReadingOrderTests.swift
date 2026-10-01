import CoreGraphics
import Testing

@testable import TextGrabCore

private func line(
  _ text: String, x: Double, y: Double, width: Double = 0.3, height: Double = 0.05
) -> RecognizedLine {
  RecognizedLine(text: text, box: CGRect(x: x, y: y, width: width, height: height))
}

@Suite struct ReadingOrderTests {
  @Test func emptyInputGivesEmptyText() {
    #expect(ReadingOrder.text([]) == "")
  }

  @Test func linesAreOrderedTopToBottom() {
    let lines = [
      line("third", x: 0.1, y: 0.5),
      line("first", x: 0.1, y: 0.1),
      line("second", x: 0.1, y: 0.3),
    ]
    #expect(ReadingOrder.text(lines) == "first\nsecond\nthird")
  }

  @Test func itemsOnTheSameRowReadLeftToRight() {
    let lines = [line("right", x: 0.6, y: 0.1), line("left", x: 0.1, y: 0.1)]
    #expect(ReadingOrder.text(lines) == "left right")
  }

  @Test func slightlyTiltedItemsStillShareARow() {
    // Vertical centers differ by 0.02, less than half the 0.05 line height.
    let lines = [line("b", x: 0.5, y: 0.12), line("a", x: 0.1, y: 0.10)]
    #expect(ReadingOrder.rows(lines).count == 1)
    #expect(ReadingOrder.text(lines) == "a b")
  }

  @Test func twoColumnsAreReadRowByRowAcrossBothColumns() {
    // Spec §4.2 groups by row, so side-by-side columns interleave line by line.
    let lines = [
      line("right 2", x: 0.6, y: 0.2), line("left 1", x: 0.1, y: 0.1),
      line("left 2", x: 0.1, y: 0.2), line("right 1", x: 0.6, y: 0.1),
    ]
    #expect(ReadingOrder.text(lines) == "left 1 right 1\nleft 2 right 2")
  }

  @Test func itemsMoreThanHalfALineApartAreSeparateRows() {
    // Vertical centers differ by 0.04, more than half the 0.05 line height.
    let lines = [line("lower", x: 0.1, y: 0.14), line("upper", x: 0.5, y: 0.10)]
    #expect(ReadingOrder.text(lines) == "upper\nlower")
  }
}
