import CoreGraphics
import CoreText
import Foundation
import ImageIO

/// Draws text into an image at test time, so the tests need no binary fixture files.
enum TextImage {
  static func render(
    _ lines: [String],
    fontSize: CGFloat = 32,
    foreground: CGColor = .black,
    background: CGColor = .white
  ) -> CGImage {
    let width = 1200
    let lineHeight = Int(fontSize * 1.6)
    let height = max(lineHeight * lines.count + 40, 80)
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(background)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
    let attributes: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): foreground,
    ]
    for (index, text) in lines.enumerated() {
      let line = CTLineCreateWithAttributedString(
        NSAttributedString(string: text, attributes: attributes))
      // Core Graphics' origin is bottom-left; draw line 0 at the top.
      let baseline = CGFloat(height - 20 - lineHeight * (index + 1)) + fontSize * 0.4
      context.textPosition = CGPoint(x: 20, y: baseline)
      CTLineDraw(line, context)
    }
    return context.makeImage()!
  }

  static func pngData(_ image: CGImage) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
  }
}
