import CoreGraphics

/// A captured screenshot. `CGImage` is immutable and thread-safe, so it's safe to pass
/// between concurrency domains even though it isn't marked `Sendable`.
public struct CapturedImage: @unchecked Sendable {
  public let cgImage: CGImage

  public init(cgImage: CGImage) {
    self.cgImage = cgImage
  }
}
