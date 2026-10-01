import AppKit

@MainActor
public protocol ClipboardWriter {
  func write(_ text: String)
}

/// Replaces whatever is on the pasteboard with plain text only.
public struct PasteboardWriter: ClipboardWriter {
  private let pasteboardName: NSPasteboard.Name

  public init(pasteboardName: NSPasteboard.Name = .general) {
    self.pasteboardName = pasteboardName
  }

  public func write(_ text: String) {
    let pasteboard = NSPasteboard(name: pasteboardName)
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }
}
