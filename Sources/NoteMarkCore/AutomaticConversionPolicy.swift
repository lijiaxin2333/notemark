/// Automatic startup and permission changes must not override an explicit pause.
public struct ConversionPermissions: Equatable {
    public let accessibility: Bool
    public let inputMonitoring: Bool

    public init(accessibility: Bool, inputMonitoring: Bool) {
        self.accessibility = accessibility
        self.inputMonitoring = inputMonitoring
    }
}

public struct AutomaticConversionPolicy {
    public private(set) var wantsConversion = true
    private var lastAttempt: ConversionPermissions?

    public init() {}

    public mutating func pause() { wantsConversion = false }

    public mutating func resume() {
        wantsConversion = true
        lastAttempt = nil
    }

    public mutating func shouldStart(permissions: ConversionPermissions, running: Bool) -> Bool {
        guard permissions.accessibility else {
            lastAttempt = nil
            return false
        }
        guard wantsConversion, !running, permissions != lastAttempt else { return false }
        // Tap creation is the final authority: don't require an unnecessary permission.
        // A failed attempt retries when permissions change, not on every timer tick.
        lastAttempt = permissions
        return true
    }
}
