import CoreGraphics

/// Puts recognized lines into natural reading order.
public enum ReadingOrder {
  /// Groups lines into rows, top to bottom. A line joins the current row when its vertical
  /// center is within half a line height (of the shorter line) of the row's first line.
  /// Lines within a row are ordered left to right.
  public static func rows(_ lines: [RecognizedLine]) -> [[RecognizedLine]] {
    var rows: [[RecognizedLine]] = []
    for line in lines.sorted(by: { $0.box.midY < $1.box.midY }) {
      if let anchor = rows.last?.first,
        abs(line.box.midY - anchor.box.midY) <= min(line.box.height, anchor.box.height) / 2
      {
        rows[rows.count - 1].append(line)
      } else {
        rows.append([line])
      }
    }
    return rows.map { $0.sorted(by: { $0.box.minX < $1.box.minX }) }
  }

  /// Row items joined with a space; rows joined with a newline.
  public static func text(_ lines: [RecognizedLine]) -> String {
    rows(lines)
      .map { row in row.map(\.text).joined(separator: " ") }
      .joined(separator: "\n")
  }
}
