import Foundation
import Testing

@testable import TextGrabCore

@Suite(.timeLimit(.minutes(1))) struct DeadlineTests {
  struct Failed: Error {}

  @Test func returnsTheResultWhenFastEnough() async throws {
    let value = try await withDeadline(.seconds(5)) { 42 }
    #expect(value == 42)
  }

  @Test func passesErrorsThrough() async {
    await #expect(throws: Failed.self) {
      try await withDeadline(.seconds(5)) { () async throws -> Int in throw Failed() }
    }
  }

  /// The operation ignores cancellation, so the deadline must not wait for it to finish.
  @Test func throwsTimedOutWithoutWaitingForAStalledOperation() async {
    let gate = Gate()
    let start = ContinuousClock.now
    await #expect(throws: DeadlineExceeded.self) {
      try await withDeadline(.milliseconds(50)) { () async -> Int in
        await gate.wait()
        return 1
      }
    }
    #expect(ContinuousClock.now - start < .seconds(2))
    await gate.open()
  }
}
