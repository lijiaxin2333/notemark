import AppKit
import ApplicationServices

/// Apple Notes as seen through NSWorkspace and Accessibility.
@MainActor enum NotesApp {
    static let bundleIdentifier = "com.apple.Notes"
    /// Requests made while deciding about a key event must not stall input.
    static let messagingTimeout: Float = 0.08

    static var frontmostProcess: NSRunningApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.bundleIdentifier == bundleIdentifier else { return nil }
        return application
    }

    static var isFrontmost: Bool { frontmostProcess != nil }

    static var runningProcess: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
    }

    /// The application element with a bounded messaging timeout.
    static func applicationElement(_ pid: pid_t) -> AXUIElement {
        let application = AXUIElement.application(pid)
        application.setMessagingTimeout(messagingTimeout)
        return application
    }

    /// Whether the snapshot's editor still has keyboard focus in the frontmost app.
    static func hasSameFocus(as snapshot: EditorSnapshot) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == snapshot.pid,
              let focused = AXUIElement.application(snapshot.pid).element(kAXFocusedUIElementAttribute) else { return false }
        return focused.isSameElement(as: snapshot.element)
    }

    static func open() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
    }
}
