import Foundation

/// The paragraph text in front of the caret, read from a UTF-16 window that
/// ends at the caret. Offsets match the Accessibility text APIs.
public struct CaretLine: Equatable, Sendable {
    /// Offset of the paragraph start inside the window.
    public let start: Int
    /// Paragraph text between its start and the caret.
    public let text: String
    /// False when the window begins mid-paragraph, so the paragraph may start
    /// earlier in the document than the sampled text shows.
    public let startIsKnown: Bool
    /// True when nothing precedes the caret in its paragraph.
    public let caretIsAtStart: Bool
    /// Document offset of the paragraph start.
    public let documentStart: Int

    public init(beforeCaret: String, windowStart: Int) {
        let window = beforeCaret as NSString
        let lineBreak = window.rangeOfCharacter(from: .newlines, options: .backwards)
        let start = lineBreak.location == NSNotFound ? 0 : NSMaxRange(lineBreak)
        self.start = start
        text = window.substring(from: start)
        startIsKnown = windowStart == 0 || lineBreak.location != NSNotFound
        caretIsAtStart = start == window.length
        documentStart = windowStart + start
    }
}

package extension NSString {
    /// Whether the UTF-16 unit at `index` is a line or paragraph separator.
    func isLineBreak(at index: Int) -> Bool {
        UnicodeScalar(character(at: index)).map { CharacterSet.newlines.contains($0) } == true
    }
}

package extension String {
    /// Whether every scalar is a line break. True for the empty string.
    var consistsOfLineBreaks: Bool {
        unicodeScalars.allSatisfy { CharacterSet.newlines.contains($0) }
    }

    /// Whether the text is empty or its first character ends the paragraph.
    var startsAtParagraphEnd: Bool {
        isEmpty || first?.isNewline == true
    }

    /// The text before the first line break, and whether a line break was found.
    func prefixBeforeLineBreak() -> (text: String, foundLineBreak: Bool) {
        let source = self as NSString
        let lineBreak = source.rangeOfCharacter(from: .newlines)
        guard lineBreak.location != NSNotFound else { return (self, false) }
        return (source.substring(to: lineBreak.location), true)
    }
}
