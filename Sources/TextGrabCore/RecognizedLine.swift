import CoreGraphics

/// One line of recognized text. `box` is in normalized image coordinates (0...1)
/// with the origin at the top-left and y growing downward.
public struct RecognizedLine: Equatable, Sendable {
  public var text: String
  public var box: CGRect

  public init(text: String, box: CGRect) {
    self.text = text
    self.box = box
  }
}
