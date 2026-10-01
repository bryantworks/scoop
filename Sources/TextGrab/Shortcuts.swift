import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  /// Default ⌘⇧2 (TextSniper's default; doesn't clash with the ⌘⇧3/4/5 screenshot shortcuts).
  static let captureText = Self("captureText", default: .init(.two, modifiers: [.command, .shift]))

  /// Smart Paste: open the Clipboard History Switcher. Default ⌃⇧1.
  static let smartPasteSwitcher = Self(
    "smartPasteSwitcher", default: .init(.one, modifiers: [.control, .shift]))

  /// Smart Paste: paste "past clipboard N". Defaults ⌃⇧2…⌃⇧6 for past clipboards 1…5.
  static let smartPaste1 = Self("smartPaste1", default: .init(.two, modifiers: [.control, .shift]))
  static let smartPaste2 = Self(
    "smartPaste2", default: .init(.three, modifiers: [.control, .shift]))
  static let smartPaste3 = Self(
    "smartPaste3", default: .init(.four, modifiers: [.control, .shift]))
  static let smartPaste4 = Self(
    "smartPaste4", default: .init(.five, modifiers: [.control, .shift]))
  static let smartPaste5 = Self("smartPaste5", default: .init(.six, modifiers: [.control, .shift]))

  /// Each fixed-position shortcut with the history position it pastes.
  static let smartPastePositions: [(position: Int, name: Self)] = [
    (1, .smartPaste1), (2, .smartPaste2), (3, .smartPaste3), (4, .smartPaste4), (5, .smartPaste5),
  ]
}
