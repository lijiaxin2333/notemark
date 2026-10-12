import Foundation

/// macOS disables an event tap whose callback is too slow, or on user request.
/// Re-enable it after isolated disables, but stop when they keep recurring.
public struct EventTapHealth: Sendable {
    public enum Action: Equatable, Sendable { case reenable, stop }

    public let limit: Int
    public let window: TimeInterval
    private var disables: [TimeInterval] = []

    public init(limit: Int = 3, window: TimeInterval = 60) {
        self.limit = limit
        self.window = window
    }

    /// Record a disable at `time`, a monotonic timestamp in seconds.
    public mutating func recordDisable(at time: TimeInterval) -> Action {
        disables = disables.filter { time - $0 < window } + [time]
        return disables.count < limit ? .reenable : .stop
    }

    public mutating func reset() { disables.removeAll() }
}
