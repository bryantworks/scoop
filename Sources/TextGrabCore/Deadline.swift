import os

public struct DeadlineExceeded: Error, Equatable {
  public let timeout: Duration
}

/// Runs `operation`, but gives up after `timeout` without waiting for it to finish.
///
/// A task group can't do this: it always waits for its children, and a stalled
/// `VNImageRequestHandler.perform` ignores cancellation. Here the operation is cancelled
/// and left to finish on its own; its result, if it ever comes, is dropped.
public func withDeadline<T: Sendable>(
  _ timeout: Duration, operation: @escaping @Sendable () async throws -> T
) async throws -> T {
  var work: Task<Void, Never>?
  var timer: Task<Void, Never>?
  defer {
    work?.cancel()
    timer?.cancel()
  }
  return try await withCheckedThrowingContinuation { continuation in
    let once = ResumeOnce(continuation)
    work = Task {
      do {
        once.resume(with: .success(try await operation()))
      } catch {
        once.resume(with: .failure(error))
      }
    }
    timer = Task {
      try? await Task.sleep(for: timeout)
      once.resume(with: .failure(DeadlineExceeded(timeout: timeout)))
    }
  }
}

/// Resumes a continuation at most once, from whichever task gets there first.
private final class ResumeOnce<T: Sendable>: Sendable {
  private let continuation: OSAllocatedUnfairLock<CheckedContinuation<T, any Error>?>

  init(_ continuation: CheckedContinuation<T, any Error>) {
    self.continuation = OSAllocatedUnfairLock(initialState: continuation)
  }

  func resume(with result: Result<T, any Error>) {
    let pending = continuation.withLock { pending in
      defer { pending = nil }
      return pending
    }
    pending?.resume(with: result)
  }
}
