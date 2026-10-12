import AppKit

enum EventDisposition {
    /// Deliver the event unchanged.
    case pass
    /// Remove the event from the stream.
    case swallow
}

/// An active session event tap whose callback runs on the main run loop.
@MainActor final class EventTap {
    typealias Handler = @MainActor (CGEventType, CGEvent) -> EventDisposition

    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var handler: Handler?

    /// Install the tap. Fails without the Accessibility or Input Monitoring permission.
    func install(events: [CGEventType], handler: @escaping Handler) -> Bool {
        remove()
        let mask = events.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: .defaultTap, eventsOfInterest: mask,
                                           callback: eventTapCallback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        self.handler = handler
        return true
    }

    /// Re-enable after macOS disabled the tap.
    func enable() {
        if let port { CGEvent.tapEnable(tap: port, enable: true) }
    }

    func remove() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        port = nil
        source = nil
        handler = nil
    }

    fileprivate func dispatch(_ type: CGEventType, _ event: CGEvent) -> EventDisposition {
        handler?(type, event) ?? .pass
    }
}

private func eventTapCallback(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent,
                              _ userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()
    // The tap's run loop source is on the main run loop, so the event never
    // leaves the main thread.
    nonisolated(unsafe) let event = event
    let swallow = MainActor.assumeIsolated { tap.dispatch(type, event) == .swallow }
    return swallow ? nil : Unmanaged.passUnretained(event)
}
