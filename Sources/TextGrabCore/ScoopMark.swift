import CoreGraphics
import Foundation

/// scoop's logo: a tilted, slotted scoop whose two slots read as lines of text. The menu bar
/// icon and the app icon are both drawn from this one shape.
public enum ScoopMark {
  /// The slots are holes cut out of the blade, so fill with this rule.
  public static var fillRule: CGPathFillRule { .evenOdd }

  /// The mark filling `rect` (a square), with y growing downward as in a flipped view.
  public static func path(in rect: CGRect) -> CGPath {
    // Designed in a 100×100 square, upright, then tilted and shrunk a little to fit.
    let transform = CGAffineTransform(translationX: -50, y: -50)
      .concatenating(CGAffineTransform(rotationAngle: -20 * .pi / 180))
      .concatenating(CGAffineTransform(scaleX: 0.9, y: 0.9))
      .concatenating(CGAffineTransform(translationX: 50, y: 50))
      .concatenating(CGAffineTransform(scaleX: rect.width / 100, y: rect.height / 100))
      .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY))

    let path = CGMutablePath()
    // Handle: rounded at the top, meeting the blade's top edge (overlapping it would cut a
    // hole there under the even-odd rule).
    path.move(to: CGPoint(x: 42, y: 36), transform: transform)
    path.addLine(to: CGPoint(x: 42, y: 12), transform: transform)
    path.addArc(
      center: CGPoint(x: 50, y: 12), radius: 8, startAngle: .pi, endAngle: 2 * .pi,
      clockwise: false, transform: transform)
    path.addLine(to: CGPoint(x: 58, y: 36), transform: transform)
    path.closeSubpath()

    // Blade: square top, rounded bottom corners.
    path.move(to: CGPoint(x: 14, y: 36), transform: transform)
    path.addLine(to: CGPoint(x: 86, y: 36), transform: transform)
    path.addLine(to: CGPoint(x: 86, y: 68), transform: transform)
    path.addQuadCurve(
      to: CGPoint(x: 62, y: 92), control: CGPoint(x: 86, y: 92), transform: transform)
    path.addLine(to: CGPoint(x: 38, y: 92), transform: transform)
    path.addQuadCurve(
      to: CGPoint(x: 14, y: 68), control: CGPoint(x: 14, y: 92), transform: transform)
    path.closeSubpath()

    // Slots, long then short, like two lines of text.
    for slot in [
      CGRect(x: 26, y: 48, width: 48, height: 10), CGRect(x: 26, y: 66, width: 30, height: 10),
    ] {
      path.addRoundedRect(in: slot, cornerWidth: 5, cornerHeight: 5, transform: transform)
    }
    return path
  }
}
