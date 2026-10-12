import Foundation

/// Restore a paragraph formatted by NoteMark once its content is empty again.
public struct EmptyParagraphCancellation: Sendable {
    public let style: ParagraphStyle
    public let paragraphStart: Int

    public init?(style: ParagraphStyle, paragraphStart: Int) {
        guard style != .body, paragraphStart >= 0 else { return nil }
        self.style = style
        self.paragraphStart = paragraphStart
    }

    /// Recover from code content or an empty paragraph whose own attributes
    /// confirm code. The previous paragraph's font alone cannot identify it.
    /// Only the evidence that applies to the caret paragraph is evaluated.
    public static func recoverCode(beforeCaret: String, windowStart: Int, selection: NSRange,
                                   isMonospacedParagraph: @autoclosure () -> Bool,
                                   isEmptyMonospacedParagraph: @autoclosure () -> Bool = false) -> EmptyParagraphCancellation? {
        guard selection.length == 0, windowStart >= 0,
              windowStart + (beforeCaret as NSString).length == selection.location else { return nil }
        let line = CaretLine(beforeCaret: beforeCaret, windowStart: windowStart)
        guard line.startIsKnown, !line.text.contains(MarkdownRule.attachmentCharacter),
              line.caretIsAtStart ? isEmptyMonospacedParagraph() : isMonospacedParagraph() else { return nil }
        return EmptyParagraphCancellation(style: .monostyled, paragraphStart: line.documentStart)
    }

    /// Keep tracking while editing this paragraph, including typing and deleting
    /// its content. A truncated text window returns nil, so long paragraphs do
    /// not lose their session before the user deletes their content again.
    public func containsCaret(beforeCaret: String, windowStart: Int, selection: NSRange) -> Bool? {
        guard windowStart >= 0,
              windowStart + (beforeCaret as NSString).length == selection.location else { return nil }
        guard selection.location >= paragraphStart else { return false }
        let line = CaretLine(beforeCaret: beforeCaret, windowStart: windowStart)
        guard line.startIsKnown else { return nil }
        return line.documentStart == paragraphStart
    }

    /// Return inserts another monospaced paragraph in Notes. Follow the code
    /// caret across those lines, including backspacing into an earlier code line.
    /// `isMonospaced` is evaluated only for a code session.
    public func followingCodeCaret(beforeCaret: String, windowStart: Int, selection: NSRange,
                                   isMonospaced: @autoclosure () -> Bool) -> EmptyParagraphCancellation? {
        guard style == .monostyled, isMonospaced(), windowStart >= 0,
              windowStart + (beforeCaret as NSString).length == selection.location else { return nil }
        let line = CaretLine(beforeCaret: beforeCaret, windowStart: windowStart)
        guard line.startIsKnown else { return nil }
        return EmptyParagraphCancellation(style: .monostyled, paragraphStart: line.documentStart)
    }

    /// `afterCaret` is nil when the paragraph's right boundary is unknown.
    public func plan(beforeCaret: String, windowStart: Int, afterCaret: String?,
                     selection: NSRange) -> EditPlan? {
        guard windowStart >= 0, selection == NSRange(location: paragraphStart, length: 0),
              windowStart + (beforeCaret as NSString).length == selection.location,
              afterCaret?.startsAtParagraphEnd == true else { return nil }
        let line = CaretLine(beforeCaret: beforeCaret, windowStart: windowStart)
        guard line.startIsKnown, line.documentStart == paragraphStart, line.caretIsAtStart else { return nil }
        return EditPlan(range: selection, original: "", conversion: .paragraph(.body))
    }
}
