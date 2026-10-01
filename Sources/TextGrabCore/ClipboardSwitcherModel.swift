import Foundation

/// Search and preview text for the Clipboard History Switcher.
public enum ClipboardSearch {
  public struct Result: Equatable, Sendable {
    /// The item's place in the history (0 = current clipboard), kept while filtering.
    public var position: Int
    public var item: ClipboardItem
  }

  /// The items whose text contains `query`, ignoring case, accents and how whitespace is laid
  /// out. An empty query keeps everything.
  public static func filter(_ items: [ClipboardItem], query: String) -> [Result] {
    let needle = collapsingWhitespace(query)
    return items.enumerated().compactMap { position, item in
      if !needle.isEmpty {
        guard let text = item.plainText,
          collapsingWhitespace(text).range(
            of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        else { return nil }
      }
      return Result(position: position, item: item)
    }
  }

  /// The item's text on one line, shortened to `maxLength` characters.
  public static func preview(_ item: ClipboardItem, maxLength: Int = 300) -> String {
    guard let text = item.plainText else { return "Formatted text" }
    let line = collapsingWhitespace(text)
    if line.isEmpty { return "Blank text" }
    return line.count > maxLength ? line.prefix(maxLength) + "…" : line
  }

  private static func collapsingWhitespace(_ text: String) -> String {
    text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
  }
}

/// What the switcher shows: the search query, matching items and which one is selected.
public struct ClipboardSwitcherModel: Sendable {
  public private(set) var items: [ClipboardItem]
  public private(set) var results: [ClipboardSearch.Result] = []
  private var selectedIndex: Int?

  public var query = "" {
    didSet { refresh() }
  }

  public init(items: [ClipboardItem]) {
    self.items = items
    refresh()
  }

  /// The history position Return would paste, or nil when nothing matches.
  public var selectedPosition: Int? {
    selectedIndex.map { results[$0].position }
  }

  public mutating func moveSelection(by offset: Int) {
    guard let selectedIndex else { return }
    self.selectedIndex = min(max(selectedIndex + offset, 0), results.count - 1)
  }

  public mutating func select(position: Int) {
    if let index = results.firstIndex(where: { $0.position == position }) {
      selectedIndex = index
    }
  }

  private mutating func refresh() {
    results = ClipboardSearch.filter(items, query: query)
    if results.isEmpty {
      selectedIndex = nil
    } else if query.allSatisfy(\.isWhitespace) {
      // Like ⌘Tab: the current clipboard is one ⌘V away already, so start on the one before.
      selectedIndex = min(1, results.count - 1)
    } else {
      selectedIndex = 0
    }
  }
}
