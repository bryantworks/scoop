import CoreGraphics
import Testing

@testable import TextGrabCore

@Suite struct ScoopMarkTests {
  /// Points in a 100×100 square (y grows downward), worked out by hand from the logo's design:
  /// the tilted scoop is rotated -20° and scaled 0.9 about the center.
  private static let handle = CGPoint(x: 40.77, y: 24.63)
  private static let bladeBetweenSlots = CGPoint(x: 53.69, y: 60.15)
  private static let firstSlot = CGPoint(x: 50.92, y: 52.54)
  private static let secondSlot = CGPoint(x: 48.85, y: 70.53)
  private static let topRightCorner = CGPoint(x: 95, y: 5)

  private func isFilled(_ point: CGPoint, in rect: CGRect) -> Bool {
    let scaled = CGPoint(
      x: rect.minX + point.x / 100 * rect.width, y: rect.minY + point.y / 100 * rect.height)
    return ScoopMark.path(in: rect).contains(scaled, using: ScoopMark.fillRule)
  }

  @Test(arguments: [
    CGRect(x: 0, y: 0, width: 100, height: 100),
    CGRect(x: 0, y: 0, width: 18, height: 18),
    CGRect(x: 100, y: 100, width: 824, height: 824),
  ])
  func fitsInsideItsSquare(rect: CGRect) {
    let bounds = ScoopMark.path(in: rect).boundingBoxOfPath
    #expect(rect.contains(bounds))
    // and isn't drawn tiny: it spans most of the square
    #expect(bounds.height > rect.height * 0.8)
  }

  @Test(arguments: [
    CGRect(x: 0, y: 0, width: 100, height: 100),
    CGRect(x: 10, y: 20, width: 200, height: 200),
  ])
  func theHandleAndBladeAreFilled(rect: CGRect) {
    #expect(isFilled(Self.handle, in: rect))
    #expect(isFilled(Self.bladeBetweenSlots, in: rect))
  }

  @Test(arguments: [
    CGRect(x: 0, y: 0, width: 100, height: 100),
    CGRect(x: 10, y: 20, width: 200, height: 200),
  ])
  func theSlotsAreHoles(rect: CGRect) {
    #expect(!isFilled(Self.firstSlot, in: rect))
    #expect(!isFilled(Self.secondSlot, in: rect))
  }

  @Test func theCornerIsEmpty() {
    #expect(!isFilled(Self.topRightCorner, in: CGRect(x: 0, y: 0, width: 100, height: 100)))
  }
}
