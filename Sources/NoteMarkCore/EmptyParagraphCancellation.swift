import Foundation

/// Restore a paragraph formatted by NoteMark once its content is empty again.
public struct EmptyParagraphCancellation {
    public let style: ParagraphStyle
    public let paragraphStart: Int

    public init?(style: ParagraphStyle, paragraphStart: Int) {
        guard style != .body, paragraphStart >= 0 else { return nil }
        self.style = style
        self.paragraphStart = paragraphStart
    }

    /// Recover from code content or an empty paragraph whose own attributes
    /// confirm code. The previous paragraph's font alone cannot identify it.
    public static func recoverCode(beforeCaret: String, windowStart: Int, selection: NSRange,
                                   isMonospacedParagraph: Bool,
                                   isEmptyMonospacedParagraph: Bool = false) -> EmptyParagraphCancellation? {
        guard selection.length == 0, windowStart >= 0,
              windowStart + (beforeCaret as NSString).length == selection.location else { return nil }
        let text = beforeCaret as NSString
        let newline = text.rangeOfCharacter(from: .newlines, options: .backwards)
        guard windowStart == 0 || newline.location != NSNotFound else { return nil }
        let start = newline.location == NSNotFound ? 0 : NSMaxRange(newline)
        guard !text.substring(from: start).contains("\u{fffc}"),
              start < text.length ? isMonospacedParagraph : isEmptyMonospacedParagraph else { return nil }
        return EmptyParagraphCancellation(style: .monostyled, paragraphStart: windowStart + start)
    }

    /// Keep tracking while editing this paragraph, including typing and deleting
    /// its content. A truncated text window returns nil, so long paragraphs do
    /// not lose their session before the user deletes their content again.
    public func containsCaret(beforeCaret: String, windowStart: Int, selection: NSRange) -> Bool? {
        guard windowStart >= 0,
              windowStart + (beforeCaret as NSString).length == selection.location else { return nil }
        guard selection.location >= paragraphStart else { return false }
        let text = beforeCaret as NSString
        let newline = text.rangeOfCharacter(from: .newlines, options: .backwards)
        let lineStart = newline.location == NSNotFound ? 0 : NSMaxRange(newline)
        guard windowStart == 0 || newline.location != NSNotFound else { return nil }
        return windowStart + lineStart == paragraphStart
    }

    /// Return inserts another monospaced paragraph in Notes. Follow the code
    /// caret across those lines, including backspacing into an earlier code line.
    public func followingCodeCaret(beforeCaret: String, windowStart: Int, selection: NSRange,
                                   isMonospaced: Bool) -> EmptyParagraphCancellation? {
        guard style == .monostyled, isMonospaced, windowStart >= 0,
              windowStart + (beforeCaret as NSString).length == selection.location else { return nil }
        let text = beforeCaret as NSString
        let newline = text.rangeOfCharacter(from: .newlines, options: .backwards)
        guard windowStart == 0 || newline.location != NSNotFound else { return nil }
        let start = newline.location == NSNotFound ? 0 : NSMaxRange(newline)
        return EmptyParagraphCancellation(style: .monostyled, paragraphStart: windowStart + start)
    }

    public func plan(beforeCaret: String, windowStart: Int, afterCaret: String,
                     selection: NSRange) -> EditPlan? {
        guard windowStart >= 0, selection == NSRange(location: paragraphStart, length: 0),
              windowStart + (beforeCaret as NSString).length == selection.location,
              afterCaret.isEmpty || afterCaret.first?.isNewline == true else { return nil }
        let text = beforeCaret as NSString
        let newline = text.rangeOfCharacter(from: .newlines, options: .backwards)
        let lineStart = newline.location == NSNotFound ? 0 : NSMaxRange(newline)
        guard windowStart == 0 || newline.location != NSNotFound,
              windowStart + lineStart == paragraphStart,
              lineStart == text.length else { return nil }
        return EditPlan(range: selection, original: "", conversion: .paragraph(.body))
    }
}
