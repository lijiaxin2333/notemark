import AppKit

/// User input that arrives while Notes acknowledges an edit. Holding it keeps
/// rapid typing in order and stops clicks from moving the caret mid-edit.
@MainActor final class HeldInput {
    private(set) var isHolding = false
    private var events: [CGEvent] = []
    private var target: pid_t = 0

    /// Start holding input typed into Notes process `pid`.
    func begin(for pid: pid_t) {
        isHolding = true
        target = pid
    }

    func hold(_ event: CGEvent) {
        if let copy = event.copy() { events.append(copy) }
    }

    /// Post held input again in its original order. If Notes lost focus in the
    /// meantime, keys still go to Notes, where they were typed.
    func release() {
        let held = events
        events.removeAll()
        isHolding = false
        let notesIsFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == target
        for event in held {
            if notesIsFrontmost || !event.isKeyboardEvent {
                // Reprocess so an immediate empty-paragraph cancellation is recognized.
                SyntheticKeyboard.requeue(event)
            } else {
                SyntheticKeyboard.deliver(event, to: target)
            }
        }
    }
}
