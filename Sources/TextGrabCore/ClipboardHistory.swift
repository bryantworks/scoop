import Foundation

/// One copied clipboard entry: its text or image representations plus where it came from.
public struct ClipboardItem: Equatable, Identifiable, Sendable {
  public static let plainTextType = "public.utf8-plain-text"
  public static let rtfType = "public.rtf"
  public static let htmlType = "public.html"
  public static let pngType = "public.png"
  public static let jpegType = "public.jpeg"
  public static let tiffType = "public.tiff"
  /// The text types Smart Paste keeps (and restores) for each item.
  public static let textTypes = [plainTextType, rtfType, htmlType]
  /// Image types in order of preference; an item keeps at most one of them.
  public static let imageTypes = [pngType, jpegType, tiffType]

  /// Identifies this copy (for example, to cache its thumbnail). Not part of its content.
  public let id = UUID()
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

  public var imageData: Data? {
    Self.imageTypes.lazy.compactMap { representations[$0] }.first
  }

  /// Total size of every representation.
  public var byteCount: Int {
    representations.values.reduce(0) { $0 + $1.count }
  }
}

/// Recent clipboard items, newest first. Index 0 is the current clipboard; index n is
/// "past clipboard n". Kept in memory only.
public struct ClipboardHistory: Sendable {
  public static let defaultCapacity = 10
  /// The history sizes offered in Settings.
  public static let allowedCapacities = 5...50
  /// Larger copies (in practice, huge images) are skipped to keep memory use reasonable.
  public static let defaultMaxItemBytes = 25 * 1024 * 1024
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

  public let maxItemBytes: Int

  public init(capacity: Int = defaultCapacity, maxItemBytes: Int = defaultMaxItemBytes) {
    self.capacity = max(1, capacity)
    self.maxItemBytes = maxItemBytes
  }

  /// Adds a new copy as the current clipboard. Skips concealed, transient, empty and oversized
  /// items.
  /// A copy whose content is already in the history moves that entry to the top instead.
  /// Returns whether the item was recorded.
  @discardableResult
  public mutating func record(_ item: ClipboardItem, pasteboardTypes: [String] = []) -> Bool {
    guard !item.representations.isEmpty, item.byteCount <= maxItemBytes,
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
