import AppKit
import Carbon.HIToolbox

/// Tags NoteMark writes into `eventSourceUserData` of events it posts.
enum SyntheticEventTag: Int64 {
    /// Posted by NoteMark itself; the event tap lets it through untouched.
    case synthetic = 0x4E4F54454D41524B // "NOTEMARK"
    /// User input held during an edit and posted again. The tap processes it
    /// like new input, so an immediate cancellation key is still recognized.
    case requeued = 0x4E4F544551554555 // "NOTEQUEU"
}

extension CGEvent {
    var syntheticTag: SyntheticEventTag? {
        SyntheticEventTag(rawValue: getIntegerValueField(.eventSourceUserData))
    }

    func setSyntheticTag(_ tag: SyntheticEventTag) {
        setIntegerValueField(.eventSourceUserData, value: tag.rawValue)
    }

    var isKeyboardEvent: Bool { [.keyDown, .keyUp, .flagsChanged].contains(type) }

    /// The text a key event types, as delivered with the event.
    var typedText: String {
        var length = 0
        var characters = [UniChar](repeating: 0, count: 16)
        keyboardGetUnicodeString(maxStringLength: characters.count, actualStringLength: &length, unicodeString: &characters)
        return String(utf16CodeUnits: characters, count: length)
    }
}

/// Posts keyboard input to Notes on NoteMark's behalf.
@MainActor enum SyntheticKeyboard {
    static func press(_ keyCode: CGKeyCode, flags: CGEventFlags = [], to pid: pid_t) {
        let source = CGEventSource(stateID: .privateState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else { continue }
            event.flags = flags
            event.setSyntheticTag(.synthetic)
            event.postToPid(pid)
        }
    }

    /// Native Delete, preserving the surrounding note and the undo stack.
    static func deleteBackward(in pid: pid_t) {
        press(CGKeyCode(kVK_Delete), to: pid)
    }

    /// Native paste creates an undoable edit. Command-V is located by the
    /// character it types, so non-QWERTY layouts paste instead of running
    /// whichever command sits on the ANSI V key.
    static func paste(in pid: pid_t, layout: KeyboardLayout) {
        press(layout.keyCode(typingWithCommand: "v") ?? CGKeyCode(kVK_ANSI_V), flags: .maskCommand, to: pid)
    }

    /// Deliver an intercepted user event to `pid` without processing it again.
    static func deliver(_ event: CGEvent, to pid: pid_t) {
        event.setSyntheticTag(.synthetic)
        event.postToPid(pid)
    }

    /// Post held user input through the HID stream so the tap sees it again.
    static func requeue(_ event: CGEvent) {
        event.setSyntheticTag(.requeued)
        event.post(tap: .cghidEventTap)
    }
}
