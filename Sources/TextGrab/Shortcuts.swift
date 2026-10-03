import KeyboardShortcuts
import TextGrabCore

extension KeyboardShortcuts.Name {
  /// Default ⌘⇧2 (TextSniper's default; doesn't clash with the ⌘⇧3/4/5 screenshot shortcuts).
  static let captureText = Self("captureText", initial: .init(.two, modifiers: [.command, .shift]))

  /// Smart Paste: open the Clipboard History Switcher. Default ⌃⇧1.
  static let smartPasteSwitcher = Self(
    "smartPasteSwitcher", initial: .init(.one, modifiers: [.control, .shift]))

  /// Smart Paste: paste history position N, shown to people as the "(N+1)th latest copy".
  /// Defaults ⌃⇧2…⌃⇧6 for positions 1…5, so the key's number matches the label's.
  static let smartPaste1 = Self("smartPaste1", initial: .init(.two, modifiers: [.control, .shift]))
  static let smartPaste2 = Self(
    "smartPaste2", initial: .init(.three, modifiers: [.control, .shift]))
  static let smartPaste3 = Self(
    "smartPaste3", initial: .init(.four, modifiers: [.control, .shift]))
  static let smartPaste4 = Self(
    "smartPaste4", initial: .init(.five, modifiers: [.control, .shift]))
  static let smartPaste5 = Self("smartPaste5", initial: .init(.six, modifiers: [.control, .shift]))

  /// Each fixed-position shortcut with the history position it pastes.
  static let smartPastePositions: [(position: Int, name: Self)] = [
    (1, .smartPaste1), (2, .smartPaste2), (3, .smartPaste3), (4, .smartPaste4), (5, .smartPaste5),
  ]

  /// Smart Paste: paste the current clipboard as ALL CAPS, lower case or Title Case.
  /// Defaults ⌃⇧U, ⌃⇧L, ⌃⇧T.
  static let smartPasteUpper = Self(
    "smartPasteUpper", initial: .init(.u, modifiers: [.control, .shift]))
  static let smartPasteLower = Self(
    "smartPasteLower", initial: .init(.l, modifiers: [.control, .shift]))
  static let smartPasteTitle = Self(
    "smartPasteTitle", initial: .init(.t, modifiers: [.control, .shift]))

  /// Each case shortcut with the case it pastes in.
  static let smartPasteCases: [(textCase: TextCase, name: Self)] = [
    (.upper, .smartPasteUpper), (.lower, .smartPasteLower), (.title, .smartPasteTitle),
  ]
}
