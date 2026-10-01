import CoreGraphics
import Vision

public protocol TextRecognizer: Sendable {
  /// Returns the text in reading order (rows joined with "\n"), or "" if there is none.
  func recognize(_ image: CapturedImage) async throws -> String
}

/// On-device text recognition with Apple Vision (the engine behind Live Text).
public struct VisionTextRecognizer: TextRecognizer {
  public init() {}

  public func recognize(_ image: CapturedImage) async throws -> String {
    try await Task.detached(priority: .userInitiated) {
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      request.automaticallyDetectsLanguage = true
      try VNImageRequestHandler(cgImage: image.cgImage).perform([request])

      let lines = (request.results ?? []).compactMap { observation -> RecognizedLine? in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        // Vision boxes are normalized with a bottom-left origin; flip to top-left.
        let box = observation.boundingBox
        return RecognizedLine(
          text: candidate.string,
          box: CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height))
      }
      return ReadingOrder.text(lines)
    }.value
  }
}
