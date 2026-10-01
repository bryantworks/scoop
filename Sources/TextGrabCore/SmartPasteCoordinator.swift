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

@MainActor
public protocol PasteboardAccess {
  /// Increases whenever anyone changes the pasteboard.
  var changeCount: Int { get }
  func readSnapshot() -> PasteboardSnapshot?
  /// Replaces the pasteboard contents and returns the resulting `changeCount`.
  func write(_ item: ClipboardItem) -> Int
}

@MainActor
public protocol KeystrokeSender {
  /// Simulates ⌘V in the frontmost app.
  func sendPaste()
}

/// Clipboard monitoring + "paste past clipboard N".
/// Pasting sets the clipboard to the chosen item (moving it to the top of the history) and
/// simulates ⌘V. Presses are queued and run one at a time, and each position is looked up when
/// its paste runs, so repeating ⌃⇧6 pastes the last six copies oldest first.
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
  private var heldPositions: Set<Int> = []
  private var queue: [Int] = []
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
    guard heldPositions.insert(position).inserted else { return }
    paste(position: position)
  }

  public func keyUp(position: Int) {
    heldPositions.remove(position)
  }

  /// Queues a paste of the item at `position` (0 = the current clipboard).
  public func paste(position: Int) {
    queue.append(position)
    guard drainTask == nil else { return }
    drainTask = Task { [weak self] in await self?.drain() }
  }

  /// Returns once every queued paste has finished.
  public func waitUntilIdle() async {
    await drainTask?.value
  }

  private func drain() async {
    while !queue.isEmpty {
      await performPaste(position: queue.removeFirst())
    }
    drainTask = nil
  }

  private func performPaste(position: Int) async {
    guard permission.isGranted() else {
      queue.removeAll()  // one explanation, not one per queued press
      feedback.show(.accessibilityNeeded)
      return
    }
    tick()  // a copy made since the last poll counts
    guard let item = history.promote(position: position) else {
      feedback.show(.nothingToPaste)
      return
    }
    lastChangeCount = pasteboard.write(item)  // our own write isn't a new copy
    keystrokes.sendPaste()
    await settle()
  }
}
