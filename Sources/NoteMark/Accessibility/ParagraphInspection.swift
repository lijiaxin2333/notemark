import AppKit
import ApplicationServices
import NoteMarkCore

/// Code-paragraph questions about one editor snapshot. Each answer reads
/// Accessibility at most once, so tracking, cancellation, and diagnostics
/// share samples instead of repeating large attributed-string requests.
@MainActor final class ParagraphInspection {
    /// Code blocks are inspected at most this far (UTF-16 units) from the caret.
    /// A truncated block is never treated as empty.
    static let codeSampleRadius = 4096
    /// Cancellation traces describe this many units on each side of the caret.
    private static let traceRadius = 128
    private static let traceParagraphLimit = 12

    let snapshot: EditorSnapshot
    private let line: CaretLine

    init(_ snapshot: EditorSnapshot) {
        self.snapshot = snapshot
        line = snapshot.caretLine
    }

    private lazy var characterCount: Int? = snapshot.element.characterCount

    /// Whether the caret paragraph is a non-empty native code paragraph.
    /// An inline code fragment at the end of ordinary prose must not arm a
    /// paragraph cancellation, so the paragraph's first character counts too.
    var hasCodeContent: Bool {
        guard snapshot.selection.length == 0, line.startIsKnown, !line.caretIsAtStart else { return false }
        return paragraphCodeState == true
    }

    /// Whether the caret sits in an empty paragraph whose own separator uses a
    /// code font. The character to its left may belong to a Body paragraph
    /// after repeated deletions, so it is never consulted.
    private(set) lazy var isEmptyMonospacedParagraph: Bool = {
        guard snapshot.selection.length == 0, let after = snapshot.after, after.startsAtParagraphEnd,
              line.startIsKnown, line.caretIsAtStart,
              let font = EditorSnapshot.renderingAttributes(of: snapshot.element, at: snapshot.selection.location)?[.font] as? NSFont
        else { return false }
        return NotesFont.isFixedPitch(font)
    }()

    private(set) lazy var currentLineIsMonospaced: Bool = {
        if let code = paragraphCodeState { return code }
        guard line.startIsKnown else { return false }
        if let font = EditorSnapshot.renderingAttributes(of: snapshot.element, at: line.documentStart)?[.font] as? NSFont {
            return NotesFont.isFixedPitch(font)
        }
        return snapshot.isMonospaced // Empty final paragraph has no character at its start.
    }()

    /// Contiguous native code paragraphs around the caret. Text and fonts are
    /// read together so neighboring Body paragraphs stay outside the block.
    private(set) lazy var codeBlock: CodeBlockContext? = {
        guard let count = characterCount, snapshot.selection.location <= count else { return nil }
        let caret = snapshot.selection.location
        let start = max(0, caret - Self.codeSampleRadius)
        let end = min(count, caret + Self.codeSampleRadius)
        return styledSample(NSRange(location: start, length: end - start), documentLength: count)?.codeBlock(caret: caret)
    }()

    /// Code state of the caret paragraph, read from its start.
    private lazy var paragraphCodeState: Bool? = {
        guard line.startIsKnown, let count = characterCount else { return nil }
        let start = line.documentStart
        let length = min(Self.codeSampleRadius, count - start)
        guard length > 0 else { return nil }
        return styledSample(NSRange(location: start, length: length), documentLength: count)?.leadingParagraphCodeState()
    }()

    private func styledSample(_ range: NSRange, documentLength: Int) -> StyledTextSample? {
        guard let text = snapshot.element.text(in: range) else { return nil }
        let styled = range.length == 0 ? NSAttributedString(string: "") : snapshot.element.attributedText(in: range)
        guard let styled, styled.length == range.length else { return nil }
        return StyledTextSample(range: range, text: text, documentLength: documentLength, fontIsCode: { index in
            guard index >= 0, index < styled.length else { return nil }
            return NotesFont.codeState(of: styled.attributes(at: index, effectiveRange: nil))
        })
    }

    /// Format and range metadata around the caret. Never serializes note text.
    func cancellationTrace(phase: String) -> CancellationTrace {
        let count = characterCount ?? -1
        let caret = snapshot.selection.location
        let context = codeBlock
        var trace = CancellationTrace(phase: phase, caret: caret, selectionLength: snapshot.selection.length,
                                      documentLength: count, contextStart: context?.range.location ?? -1,
                                      contextLength: context?.range.length ?? -1,
                                      contextEmpty: context?.text.consistsOfLineBreaks ?? false)
        let start = max(0, caret - Self.traceRadius)
        let end = min(count, caret + Self.traceRadius)
        let range = NSRange(location: start, length: end - start)
        guard end >= start, let sample = snapshot.element.text(in: range) else { return trace }
        let source = sample as NSString
        let styled = snapshot.element.attributedText(in: range)
        func fontName(_ index: Int) -> String {
            guard let styled, index >= start, index - start < styled.length else { return "unavailable" }
            let attributes = styled.attributes(at: index - start, effectiveRange: nil)
            return NotesFont.font(in: attributes)?.fontName ??
                (attributes[NotesFont.accessibilityFontKey] as? [String: Any])?[NotesFont.accessibilityFontNameKey] as? String ??
                "unavailable"
        }
        var paragraphs: [ParagraphFonts] = []
        var paragraphStart = 0
        for index in 0...source.length where index == source.length || source.isLineBreak(at: index) {
            paragraphs.append(ParagraphFonts(start: start + paragraphStart, length: index - paragraphStart,
                                             firstFont: fontName(start + paragraphStart),
                                             lastFont: fontName(start + max(paragraphStart, index - 1)),
                                             separatorFont: fontName(start + index)))
            paragraphStart = index + 1
        }
        trace.paragraphs = Array(paragraphs.suffix(Self.traceParagraphLimit))
        return trace
    }
}
