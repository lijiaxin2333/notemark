import Foundation

/// Native formatting can update selection after its command returns. Keep input
/// queued until the original caret survives that asynchronous update.
@MainActor public enum SelectionRestoration {
    public static func restore(
        _ target: NSRange, attempts: Int = 15, settlingAttempts: Int = 6, confirmations: Int = 3,
        isValid: () -> Bool, read: () -> NSRange?, write: (NSRange) -> Bool,
        pause: () async throws -> Void = { try await Task.sleep(nanoseconds: 20_000_000) }
    ) async -> Bool {
        guard attempts > 0, settlingAttempts > 0, confirmations > 0,
              target.location >= 0, target.length >= 0, isValid(), !Task.isCancelled else { return false }
        _ = write(target)
        var stable = 0
        for attempt in 1...attempts {
            do { try await pause() } catch { return false }
            guard isValid(), !Task.isCancelled else { return false }
            if read() == target {
                stable += 1
            } else {
                stable = 0
                guard isValid() else { return false }
                _ = write(target)
            }
            if attempt >= settlingAttempts, stable >= confirmations, isValid() { return true }
        }
        return false
    }
}
