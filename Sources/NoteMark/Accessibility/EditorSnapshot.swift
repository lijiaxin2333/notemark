import AppKit
import ApplicationServices
import NoteMarkCore

/// The focused Notes text area and the text around its caret at one moment.
struct EditorSnapshot {
    enum Purpose {
        /// Converting text: requires a caret and no input-method marked text.
        case editing
        /// Following the editor: allows selections and input-method composition.
        case observation
    }

    /// Text before the caret read for paragraph rules.
    static let precedingTextLimit = 512
    /// Text after the caret read before turning an existing paragraph into a list.
    static let paragraphTailLimit = 512

    let pid: pid_t
    let element: AXUIElement
    let selection: NSRange
    /// Document offset of `before`.
    let windowStart: Int
    let before: String
    /// The rest of the caret paragraph (only its first character when that is
    /// enough), or nil when the paragraph's right boundary is unknown.
    let after: String?
    /// The text read after the caret, even when it ended before the paragraph
    /// did; nil when nothing was read. For status diagnostics only.
    let sampledTail: String?
    /// Attributes of the character before the caret, for rendering inline text.
    let baseAttributes: [NSAttributedString.Key: Any]?
    /// Whether the character before the caret uses a fixed-pitch font.
    let isMonospaced: Bool

    var rightBoundaryKnown: Bool { after != nil }
    var caretLine: CaretLine { CaretLine(beforeCaret: before, windowStart: windowStart) }

    @MainActor static func capture(_ purpose: Purpose = .editing) -> EditorSnapshot? {
        guard let process = NotesApp.frontmostProcess else { return nil }
        let application = NotesApp.applicationElement(process.processIdentifier)
        guard let editor = application.element(kAXFocusedUIElementAttribute), editor.role == kAXTextAreaRole,
              let selection = editor.selectedRange, purpose == .observation || selection.length == 0 else { return nil }
        editor.setMessagingTimeout(NotesApp.messagingTimeout)
        guard editor.isSettable(kAXSelectedTextRangeAttribute) else { return nil }
        // Some editors expose marked text while an IME is composing. Never replace it.
        if purpose == .editing, InputMethodMonitor.hasMarkedText(in: editor, selection: selection) { return nil }
        if let ranges = editor.attribute(kAXSelectedTextRangesAttribute) as? [Any], ranges.count > 1 { return nil }
        let windowStart = max(0, selection.location - precedingTextLimit)
        guard let before = editor.text(in: NSRange(location: windowStart, length: selection.location - windowStart)) else { return nil }
        let count = editor.characterCount
        let after: String?
        let sampledTail: String?
        if let count, selection.location < count {
            if MarkdownRule.isListMarker(CaretLine(beforeCaret: before, windowStart: windowStart).text) {
                // Inspect the rest of this paragraph before changing an existing line to a list.
                // A truncated tail or an image anchor must not be treated as plain text.
                let length = min(paragraphTailLimit, count - selection.location)
                guard let sample = editor.text(in: NSRange(location: selection.location, length: length)) else { return nil }
                let tail = sample.prefixBeforeLineBreak()
                after = tail.foundLineBreak || length == count - selection.location ? tail.text : nil
                sampledTail = tail.text
            } else {
                guard let next = editor.text(in: NSRange(location: selection.location, length: 1)) else { return nil }
                after = next
                sampledTail = next
            }
        } else if count == selection.location {
            after = ""
            sampledTail = ""
        } else {
            // Without a right-hand boundary, paragraph conversion is unsafe.
            after = nil
            sampledTail = nil
        }
        let attributes = selection.location > 0 ? renderingAttributes(of: editor, at: selection.location - 1) : nil
        let isMonospaced = (attributes?[.font] as? NSFont).map(NotesFont.isFixedPitch) ?? false
        return EditorSnapshot(pid: process.processIdentifier, element: editor, selection: selection,
                              windowStart: windowStart, before: before, after: after, sampledTail: sampledTail,
                              baseAttributes: attributes, isMonospaced: isMonospaced)
    }

    /// Rendering attributes of the character at `index`.
    static func renderingAttributes(of element: AXUIElement, at index: Int) -> [NSAttributedString.Key: Any]? {
        guard let attributed = element.attributedText(in: NSRange(location: index, length: 1)),
              attributed.length > 0 else { return nil }
        return NotesFont.renderingAttributes(from: attributed.attributes(at: 0, effectiveRange: nil))
    }

    /// The caret rectangle in AppKit screen coordinates, for anchoring the slash menu.
    func caretBounds() -> CGRect? {
        let precedingCharacter = NSRange(location: max(0, selection.location - 1), length: selection.location > 0 ? 1 : 0)
        for range in [selection, precedingCharacter] {
            if let rectangle = element.bounds(for: range), rectangle.height > 0 {
                return Self.appKitRect(rectangle)
            }
        }
        // Some Notes versions expose the editor bounds but not a caret rectangle.
        // Anchor near the editor's top-left corner instead.
        if let origin = AXValueConversion.point(element.attribute(kAXPositionAttribute)),
           let size = AXValueConversion.size(element.attribute(kAXSizeAttribute)), size.width > 0, size.height > 0 {
            return Self.appKitRect(CGRect(x: origin.x + 20, y: origin.y + 20, width: 1, height: 18))
        }
        return nil
    }

    /// Accessibility uses a top-left origin on the primary display; AppKit uses bottom-left.
    private static func appKitRect(_ rectangle: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: rectangle.minX, y: primaryHeight - rectangle.maxY,
                      width: max(1, rectangle.width), height: rectangle.height)
    }
}
