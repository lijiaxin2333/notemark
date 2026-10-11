import Foundation

/// Only an empty heading just created by NoteMark can be cancelled.
public struct EmptyHeadingCancellation {
    public let paragraphStart: Int

    public init?(style: ParagraphStyle, paragraphStart: Int) {
        guard [.title, .heading, .subheading].contains(style), paragraphStart >= 0 else { return nil }
        self.paragraphStart = paragraphStart
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
