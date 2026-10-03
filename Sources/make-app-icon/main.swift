// Draws scoop's app icon into an .iconset folder for `iconutil -c icns`.
// Usage: make-app-icon <output.iconset>      (run by scripts/bundle.sh)
import CoreGraphics
import Foundation
import ImageIO
import TextGrabCore
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write(Data("usage: make-app-icon <output.iconset>\n".utf8))
  exit(2)
}
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

let coral = CGColor(srgbRed: 0xF1 / 255, green: 0x54 / 255, blue: 0x36 / 255, alpha: 1)
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
let shadow = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.3)

/// One icon `pixels` wide, laid out on Apple's macOS icon grid: on a 1024 canvas the rounded
/// square is 824 wide with a 185 corner radius, leaving room for its shadow.
func drawIcon(pixels: Int) -> CGImage? {
  guard
    let context = CGContext(
      data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  else { return nil }
  let unit = CGFloat(pixels) / 1024
  // ScoopMark is drawn with y growing downward.
  context.translateBy(x: 0, y: CGFloat(pixels))
  context.scaleBy(x: 1, y: -1)

  let tile = CGRect(x: 100, y: 100, width: 824, height: 824).applying(
    CGAffineTransform(scaleX: unit, y: unit))
  context.saveGState()
  // Shadow offsets ignore the flip above: negative is down.
  context.setShadow(offset: CGSize(width: 0, height: -10 * unit), blur: 24 * unit, color: shadow)
  context.addPath(
    CGPath(roundedRect: tile, cornerWidth: 185 * unit, cornerHeight: 185 * unit, transform: nil))
  context.setFillColor(coral)
  context.fillPath()
  context.restoreGState()

  let markSide = tile.width * 0.625
  let mark = CGRect(
    x: tile.midX - markSide / 2, y: tile.midY - markSide / 2, width: markSide, height: markSide)
  context.addPath(ScoopMark.path(in: mark))
  context.setFillColor(white)
  context.fillPath(using: ScoopMark.fillRule)
  return context.makeImage()
}

// The file names and sizes iconutil expects.
let images: [(name: String, pixels: Int)] = [16, 32, 128, 256, 512].flatMap { points in
  [("icon_\(points)x\(points).png", points), ("icon_\(points)x\(points)@2x.png", points * 2)]
}
for (name, pixels) in images {
  let url = folder.appendingPathComponent(name)
  guard let image = drawIcon(pixels: pixels),
    let destination = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.png.identifier as CFString, 1, nil)
  else {
    FileHandle.standardError.write(Data("make-app-icon: couldn't draw \(name)\n".utf8))
    exit(1)
  }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("make-app-icon: couldn't write \(url.path)\n".utf8))
    exit(1)
  }
}
