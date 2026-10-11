import Foundation

/// Allow the editor to acknowledge input that preceded the intercepted delimiter.
@MainActor public enum InputAcknowledgement {
    public static func wait<Value>(
        attempts: Int = 6, isValid: () -> Bool, read: () -> Value?,
        pause: () async throws -> Void = { try await Task.sleep(nanoseconds: 15_000_000) }
    ) async -> Value? {
        guard attempts > 0 else { return nil }
        for _ in 0..<attempts {
            do { try await pause() } catch { return nil }
            guard !Task.isCancelled, isValid() else { return nil }
            if let value = read(), isValid() { return value }
        }
        return nil
    }
}
