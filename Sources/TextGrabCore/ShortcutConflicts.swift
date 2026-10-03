/// The names whose shortcut is also assigned to another name. Cleared (nil) shortcuts are ignored.
///
/// Settings uses this to warn when two scoop actions share keys: both would run on one press.
public func conflictingNames<Name: Hashable, Key: Hashable>(
  _ assignments: [(name: Name, key: Key?)]
) -> Set<Name> {
  var namesByKey: [Key: [Name]] = [:]
  for assignment in assignments {
    guard let key = assignment.key else { continue }
    namesByKey[key, default: []].append(assignment.name)
  }
  return Set(namesByKey.values.filter { $0.count > 1 }.joined())
}
