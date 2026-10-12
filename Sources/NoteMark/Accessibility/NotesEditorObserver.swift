import AppKit
import ApplicationServices

/// Reports focus, text, and selection changes in Notes through an AXObserver.
/// IME commits and pastes change the editor without a usable key event.
@MainActor final class NotesEditorObserver {
    var onChange: (() -> Void)?

    private static let editorNotifications = [kAXValueChangedNotification, kAXSelectedTextChangedNotification]

    private var observer: AXObserver?
    private var application: AXUIElement?
    private var editor: AXUIElement?

    private var refcon: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }

    /// Observe focus changes in `process`, replacing an observer of an earlier
    /// Notes process. Returns false when no observer is available.
    func observe(_ process: NSRunningApplication) -> Bool {
        let candidate = NotesApp.applicationElement(process.processIdentifier)
        if let application, application.isSameElement(as: candidate) { return true }
        removeObserver()
        var created: AXObserver?
        guard AXObserverCreate(process.processIdentifier, notesObserverCallback, &created) == .success,
              let created else { return false }
        observer = created
        application = candidate
        AXObserverAddNotification(created, candidate, kAXFocusedUIElementChangedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        return true
    }

    /// Follow the focused element. Returns true when focus moved to a different
    /// element; text and selection changes are observed only in text areas.
    func bindFocusedEditor() -> Bool {
        guard let observer, let application,
              let focused = application.element(kAXFocusedUIElementAttribute) else { return false }
        if let editor, editor.isSameElement(as: focused) { return false }
        if let editor {
            for name in Self.editorNotifications { AXObserverRemoveNotification(observer, editor, name as CFString) }
        }
        editor = focused
        focused.setMessagingTimeout(NotesApp.messagingTimeout)
        guard focused.role == kAXTextAreaRole else { return true }
        for name in Self.editorNotifications {
            AXObserverAddNotification(observer, focused, name as CFString, refcon)
        }
        return true
    }

    func stop() {
        removeObserver()
        application = nil
    }

    private func removeObserver() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        editor = nil
    }

    fileprivate func notify() { onChange?() }
}

private func notesObserverCallback(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString,
                                   _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let target = Unmanaged<NotesEditorObserver>.fromOpaque(refcon).takeUnretainedValue()
    // The observer's run loop source is on the main run loop.
    MainActor.assumeIsolated { target.notify() }
}
