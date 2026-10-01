import AppKit

/// `PasteboardAccess` over a real `NSPasteboard`, keeping only the text types Smart Paste
/// supports.
@MainActor
public struct SystemPasteboard: PasteboardAccess {
  public struct SourceApp: Sendable {
    public var bundleID: String?
    public var name: String?

    public init(bundleID: String?, name: String?) {
      self.bundleID = bundleID
      self.name = name
    }
  }

  private let pasteboard: NSPasteboard
  private let sourceApp: @MainActor () -> SourceApp?

  /// `sourceApp` is asked at read time; by default it's the frontmost app.
  public init(
    pasteboardName: NSPasteboard.Name = .general,
    sourceApp: @escaping @MainActor () -> SourceApp? = SystemPasteboard.frontmostApp
  ) {
    pasteboard = NSPasteboard(name: pasteboardName)
    self.sourceApp = sourceApp
  }

  public static func frontmostApp() -> SourceApp? {
    NSWorkspace.shared.frontmostApplication.map {
      SourceApp(bundleID: $0.bundleIdentifier, name: $0.localizedName)
    }
  }

  public var changeCount: Int { pasteboard.changeCount }

  public func readSnapshot() -> PasteboardSnapshot? {
    guard let types = pasteboard.types?.map(\.rawValue), !types.isEmpty else { return nil }
    let source = sourceApp()
    var item = ClipboardItem(
      representations: [:], sourceBundleID: source?.bundleID, sourceAppName: source?.name)
    // Don't even read a secret's data; `ClipboardHistory.record` skips the item.
    let isSecret =
      types.contains(ClipboardHistory.concealedType)
      || types.contains(ClipboardHistory.transientType)
    if !isSecret {
      for type in ClipboardItem.supportedTypes {
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType(type)) {
          item.representations[type] = data
        }
      }
    }
    return PasteboardSnapshot(item: item, types: types)
  }

  public func write(_ item: ClipboardItem) -> Int {
    pasteboard.clearContents()
    for (type, data) in item.representations {
      pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type))
    }
    return pasteboard.changeCount
  }
}
