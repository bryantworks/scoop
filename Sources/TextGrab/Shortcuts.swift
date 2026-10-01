import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  /// Default ⌘⇧2 (TextSniper's default; doesn't clash with the ⌘⇧3/4/5 screenshot shortcuts).
  static let captureText = Self("captureText", default: .init(.two, modifiers: [.command, .shift]))
}
