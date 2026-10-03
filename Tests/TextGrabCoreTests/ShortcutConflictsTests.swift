import Testing

@testable import TextGrabCore

private typealias Assignments = [(name: String, key: String?)]

@Suite struct ShortcutConflictsTests {
  @Test func distinctShortcutsDontConflict() {
    let assignments: Assignments = [("capture", "⌘⇧2"), ("paste1", "⌃⇧2")]
    #expect(conflictingNames(assignments).isEmpty)
  }

  @Test func sharedShortcutFlagsBothNames() {
    let assignments: Assignments = [("capture", "⌃⇧2"), ("paste1", "⌃⇧2"), ("paste2", "⌃⇧3")]
    #expect(conflictingNames(assignments) == ["capture", "paste1"])
  }

  @Test func flagsEveryNameInAGroup() {
    let assignments: Assignments = [("a", "x"), ("b", "x"), ("c", "x"), ("d", "y")]
    #expect(conflictingNames(assignments) == ["a", "b", "c"])
  }

  /// Cleared shortcuts (nil) never conflict with each other.
  @Test func clearedShortcutsAreIgnored() {
    let assignments: Assignments = [("a", nil), ("b", nil), ("c", "x")]
    #expect(conflictingNames(assignments).isEmpty)
  }
}
