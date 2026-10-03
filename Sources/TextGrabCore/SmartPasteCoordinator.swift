import Foundation

/// What the clipboard holds right now, as read from the pasteboard.
public struct PasteboardSnapshot: Sendable {
  public var item: ClipboardItem
  /// Every type on the pasteboard, including marker types like `ClipboardHistory.concealedType`.
  public var types: [String]

  public init(item: ClipboardItem, types: [String]) {
    self.item = item
    self.types = types
  }
}

/// Everything on the pasteboard, every item and type, so it can be put back exactly.
public struct PasteboardContents: Equatable, Sendable {
  /// One entry per pasteboard item: type identifier → bytes.
  public var items: [[String: Data]]

  public init(items: [[String: Data]]) {
    self.items = items
  }
}

@MainActor
public protocol PasteboardAccess {
  /// Increases whenever anyone changes the pasteboard.
  var changeCount: Int { get }
  func readSnapshot() -> PasteboardSnapshot?
  /// Replaces the pasteboard contents and returns the resulting `changeCount`.
  func write(_ item: ClipboardItem) -> Int
  /// Copies every item and type on the pasteboard, or nil when it's empty.
  func saveContents() -> PasteboardContents?
  /// Puts saved contents back and returns the resulting `changeCount`.
  func restore(_ contents: PasteboardContents) -> Int
}

@MainActor
public protocol KeystrokeSender {
  /// Simulates ⌘V in the frontmost app.
  func sendPaste()
}

/// Clipboard monitoring + "paste past clipboard N" + "paste in a different case".
/// Pasting sets the clipboard to the chosen item (moving it to the top of the history) and
/// simulates ⌘V. A case paste instead pastes the current clipboard's text converted, then puts
/// the clipboard back exactly as it was. Presses are queued and run one at a time, and each
/// position is looked up when its paste runs, so repeating ⌃⇧6 pastes the last six copies oldest
/// first.
@MainActor
public final class SmartPasteCoordinator {
  private let pasteboard: any PasteboardAccess
  private let keystrokes: any KeystrokeSender
  private let permission: any AccessibilityPermission
  private let feedback: any Feedback
  /// Waits after each ⌘V so the target app reads the clipboard before it changes again.
  private let settle: @MainActor () async -> Void

  public private(set) var history: ClipboardHistory
  /// The pasteboard state already accounted for: the last copy recorded, or our own write.
  private var lastChangeCount: Int?
  private var heldKeys: Set<PasteRequest> = []
  private var queue: [PasteRequest] = []
  private var drainTask: Task<Void, Never>?

  public init(
    pasteboard: any PasteboardAccess,
    keystrokes: any KeystrokeSender,
    permission: any AccessibilityPermission,
    feedback: any Feedback,
    capacity: Int = ClipboardHistory.defaultCapacity,
    settle: @escaping @MainActor () async -> Void
  ) {
    self.pasteboard = pasteboard
    self.keystrokes = keystrokes
    self.permission = permission
    self.feedback = feedback
    self.settle = settle
    history = ClipboardHistory(capacity: capacity)
    tick()  // the current clipboard becomes the first item
  }

  /// Changes how many items are kept (within `ClipboardHistory.allowedCapacities`); shrinking
  /// drops the oldest.
  public func setHistoryCapacity(_ capacity: Int) {
    let range = ClipboardHistory.allowedCapacities
    history.capacity = min(max(capacity, range.lowerBound), range.upperBound)
  }

  /// Asks for Accessibility permission (system prompt) if it isn't granted yet.
  public func requestPermissionIfNeeded() {
    if !permission.isGranted() { permission.request() }
  }

  /// Polled regularly: records a new copy if the pasteboard changed since we last looked.
  public func tick() {
    let changeCount = pasteboard.changeCount
    guard changeCount != lastChangeCount else { return }
    lastChangeCount = changeCount
    if let snapshot = pasteboard.readSnapshot() {
      history.record(snapshot.item, pasteboardTypes: snapshot.types)
    }
  }

  /// A fixed-position shortcut went down. Auto-repeat (another key-down with no key-up in
  /// between) is ignored.
  public func keyDown(position: Int) {
    keyDown(.position(position))
  }

  public func keyUp(position: Int) {
    heldKeys.remove(.position(position))
  }

  /// A case shortcut went down. Auto-repeat is ignored, as for the position shortcuts.
  public func keyDown(converting textCase: TextCase) {
    keyDown(.converted(textCase))
  }

  public func keyUp(converting textCase: TextCase) {
    heldKeys.remove(.converted(textCase))
  }

  /// Queues a paste of the item at `position` (0 = the current clipboard).
  public func paste(position: Int) {
    enqueue(.position(position))
  }

  private func keyDown(_ request: PasteRequest) {
    guard heldKeys.insert(request).inserted else { return }
    enqueue(request)
  }

  private func enqueue(_ request: PasteRequest) {
    queue.append(request)
    guard drainTask == nil else { return }
    drainTask = Task { [weak self] in await self?.drain() }
  }

  /// Returns once every queued paste has finished.
  public func waitUntilIdle() async {
    await drainTask?.value
  }

  private func drain() async {
    while !queue.isEmpty {
      await perform(queue.removeFirst())
    }
    drainTask = nil
  }

  private func perform(_ request: PasteRequest) async {
    guard permission.isGranted() else {
      queue.removeAll()  // one explanation, not one per queued press
      feedback.show(.accessibilityNeeded)
      return
    }
    tick()  // a copy made since the last poll counts
    switch request {
    case .position(let position): await performPaste(position: position)
    case .converted(let textCase): await performPaste(converting: textCase)
    }
  }

  private func performPaste(position: Int) async {
    guard let item = history.promote(position: position) else {
      feedback.show(.nothingToPaste)
      return
    }
    lastChangeCount = pasteboard.write(item)  // our own write isn't a new copy
    keystrokes.sendPaste()
    await settle()
  }

  /// Reads the live clipboard rather than the history, so a secret (which the history skips)
  /// is refused instead of an older item being pasted in its place.
  private func performPaste(converting textCase: TextCase) async {
    guard let snapshot = pasteboard.readSnapshot(),
      !snapshot.types.contains(ClipboardHistory.concealedType),
      !snapshot.types.contains(ClipboardHistory.transientType),
      let text = snapshot.item.plainText,
      let original = pasteboard.saveContents()
    else {
      feedback.show(.nothingToPaste)
      return
    }
    let written = pasteboard.write(ClipboardItem(plainText: textCase.apply(to: text)))
    lastChangeCount = written
    keystrokes.sendPaste()
    await settle()
    // Someone copied something while we waited: that's the clipboard now, so leave it.
    guard pasteboard.changeCount == written else { return }
    lastChangeCount = pasteboard.restore(original)
  }
}

private enum PasteRequest: Hashable {
  case position(Int)
  case converted(TextCase)
}
