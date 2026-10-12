import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Detects input-method composition, during which keys belong to the IME and
/// text must never be replaced.
@MainActor enum InputMethodMonitor {
    private static let markedTextRangeAttribute = "AXMarkedTextRange"
    private static let candidateWindowTimeout: Float = 0.04
    private static let candidateWindowSubroles: Set<String> = [
        kAXSystemDialogSubrole, kAXSystemFloatingWindowSubrole, kAXFloatingWindowSubrole
    ]

    static func isComposing() -> Bool {
        guard let process = NotesApp.frontmostProcess,
              let editor = NotesApp.applicationElement(process.processIdentifier).element(kAXFocusedUIElementAttribute)
        else { return false }
        editor.setMessagingTimeout(NotesApp.messagingTimeout)
        return hasMarkedText(in: editor, selection: editor.selectedRange) || hasVisibleCandidateWindow()
    }

    /// WeType does not expose AXMarkedTextRange or markedClauseSegment in Notes.
    /// Its candidate UI is a system dialog owned by the selected input method.
    static func hasVisibleCandidateWindow() -> Bool {
        inputMethodWindows().contains { window in
            guard let subrole = window.string(kAXSubroleAttribute), candidateWindowSubroles.contains(subrole) else { return false }
            return window.number(kAXMinimizedAttribute)?.boolValue != true
        }
    }

    static func hasMarkedText(in editor: AXUIElement, selection: NSRange?) -> Bool {
        if (AXValueConversion.range(editor.attribute(markedTextRangeAttribute))?.length ?? 0) > 0 { return true }
        // Some text areas expose composition attributes instead of a marked range.
        // Check both sides of the selection because the IME caret can be inside it.
        guard let selection else { return false }
        for index in Set([max(0, selection.location - 1), selection.location]) {
            if let text = editor.attributedText(in: NSRange(location: index, length: 1)), text.length > 0,
               text.attribute(.markedClauseSegment, at: 0, effectiveRange: nil) != nil {
                return true
            }
        }
        return false
    }

    private static func inputMethodWindows() -> [AXUIElement] {
        guard let owner = currentInputSourceBundleIdentifier() else { return [] }
        return NSRunningApplication.runningApplications(withBundleIdentifier: owner).flatMap { process in
            let application = AXUIElement.application(process.processIdentifier)
            application.setMessagingTimeout(candidateWindowTimeout)
            // Some input methods omit AXWindows but expose their candidate dialog
            // as an application child instead.
            return application.elements(kAXWindowsAttribute) + application.elements(kAXChildrenAttribute)
        }
    }

    private static func currentInputSourceBundleIdentifier() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyBundleID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
    }
}
