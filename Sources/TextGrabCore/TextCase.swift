/// A case Smart Paste can convert text to before pasting it.
public enum TextCase: Sendable, CaseIterable {
  /// ALL CAPS.
  case upper
  /// lower case.
  case lower
  /// Title Case: every word's first letter capitalized, the rest lowercased.
  case title

  public func apply(to text: String) -> String {
    switch self {
    case .upper: text.uppercased()
    case .lower: text.lowercased()
    case .title: Self.titleCased(text)
    }
  }

  /// A word is anything between whitespace. Leading punctuation is skipped, so "(me)" becomes
  /// "(Me)", but a word starting with a digit keeps its letters lowercase ("3rd").
  private static func titleCased(_ text: String) -> String {
    var result = ""
    var atWordStart = true
    for character in text {
      if character.isWhitespace {
        atWordStart = true
        result.append(character)
      } else if atWordStart && character.isLetter {
        atWordStart = false
        result += character.uppercased()
      } else {
        if character.isNumber { atWordStart = false }
        result += character.lowercased()
      }
    }
    return result
  }
}
