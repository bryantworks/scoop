import Foundation

/// One copied clipboard entry: its text representations plus where it came from.
public struct ClipboardItem: Equatable, Sendable {
  public static let plainTextType = "public.utf8-plain-text"
  public static let rtfType = "public.rtf"
  public static let htmlType = "public.html"
  /// The text types Smart Paste keeps (and restores) for each item.
  public static let supportedTypes = [plainTextType, rtfType, htmlType]

  /// Pasteboard type identifier → bytes.
  public var representations: [String: Data]
  public var sourceBundleID: String?
  public var sourceAppName: String?
  public var copiedAt: Date

  public init(
    representations: [String: Data], sourceBundleID: String? = nil,
    sourceAppName: String? = nil, copiedAt: Date = Date()
  ) {
    self.representations = representations
    self.sourceBundleID = sourceBundleID
    self.sourceAppName = sourceAppName
    self.copiedAt = copiedAt
  }

  public init(
    plainText: String, sourceBundleID: String? = nil, sourceAppName: String? = nil,
    copiedAt: Date = Date()
  ) {
    self.init(
      representations: [Self.plainTextType: Data(plainText.utf8)],
      sourceBundleID: sourceBundleID, sourceAppName: sourceAppName, copiedAt: copiedAt)
  }

  public var plainText: String? {
    representations[Self.plainTextType].flatMap { String(data: $0, encoding: .utf8) }
  }
}

/// Recent clipboard items, newest first. Index 0 is the current clipboard; index n is
/// "past clipboard n". Kept in memory only.
public struct ClipboardHistory: Sendable {
  public static let defaultCapacity = 10
  /// Marker types password managers put on secrets (see nspasteboard.org).
  public static let concealedType = "org.nspasteboard.ConcealedType"
  public static let transientType = "org.nspasteboard.TransientType"

  public private(set) var items: [ClipboardItem] = []

  public var capacity: Int {
    didSet {
      capacity = max(1, capacity)
      trim()
    }
  }

  public init(capacity: Int = defaultCapacity) {
    self.capacity = max(1, capacity)
  }

  /// Adds a new copy as the current clipboard. Skips concealed, transient and empty items.
  /// A copy whose content is already in the history moves that entry to the top instead.
  /// Returns whether the item was recorded.
  @discardableResult
  public mutating func record(_ item: ClipboardItem, pasteboardTypes: [String] = []) -> Bool {
    guard !item.representations.isEmpty,
      !pasteboardTypes.contains(Self.concealedType),
      !pasteboardTypes.contains(Self.transientType)
    else { return false }
    items.removeAll { $0.representations == item.representations }
    items.insert(item, at: 0)
    trim()
    return true
  }

  public func item(at position: Int) -> ClipboardItem? {
    items.indices.contains(position) ? items[position] : nil
  }

  /// Makes the item at `position` the current clipboard, shifting the items above it back
  /// by one. Returns that item, or nil (and changes nothing) for an empty position.
  public mutating func promote(position: Int) -> ClipboardItem? {
    guard items.indices.contains(position) else { return nil }
    let item = items.remove(at: position)
    items.insert(item, at: 0)
    return item
  }

  public mutating func clear() {
    items.removeAll()
  }

  private mutating func trim() {
    if items.count > capacity { items.removeLast(items.count - capacity) }
  }
}
