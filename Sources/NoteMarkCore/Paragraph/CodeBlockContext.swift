import Foundation

public enum CodeBlockCancellationIntent: Sendable {
    case backwardDeletion
    case forwardDeletion
    case escape
}

/// A bounded view of contiguous native monospaced paragraphs around the caret.
public struct CodeBlockContext: Equatable, Sendable {
    public let range: NSRange
    public let text: String

    public static func read(text: String, windowStart: Int, documentLength: Int, caret: Int,
                            currentLineIsCode: Bool,
                            isCodeLine: (NSRange) -> Bool?) -> CodeBlockContext? {
        let source = text as NSString
        guard currentLineIsCode, windowStart >= 0, documentLength >= 0,
              windowStart + source.length <= documentLength,
              caret >= windowStart, caret <= windowStart + source.length else { return nil }
        var lines: [NSRange] = []
        var start = 0
        for index in 0..<source.length where source.isLineBreak(at: index) {
            // A CRLF pair is one paragraph boundary.
            if index > 0, source.character(at: index) == 10, source.character(at: index - 1) == 13 {
                start = index + 1; continue
            }
            lines.append(NSRange(location: start, length: index - start))
            start = index + 1
        }
        lines.append(NSRange(location: start, length: source.length - start))
        let offset = caret - windowStart
        guard let current = lines.lastIndex(where: { $0.location <= offset && offset <= NSMaxRange($0) }) else { return nil }
        var first = current
        var last = current
        while first > 0 {
            guard let code = isCodeLine(lines[first - 1]) else { return nil }
            guard code else { break }
            first -= 1
        }
        while last + 1 < lines.count {
            guard let code = isCodeLine(lines[last + 1]) else { return nil }
            guard code else { break }
            last += 1
        }
        guard first > 0 || windowStart == 0,
              last + 1 < lines.count || windowStart + source.length == documentLength else { return nil }
        let range = NSRange(location: lines[first].location,
                            length: NSMaxRange(lines[last]) - lines[first].location)
        return CodeBlockContext(range: NSRange(location: windowStart + range.location, length: range.length),
                                text: source.substring(with: range))
    }

    /// Delete internal line breaks natively while they remain in the requested
    /// direction. At the block boundary, cancel the current empty paragraph
    /// instead of merging the code into surrounding Body paragraphs.
    public func cancellationPlan(selection: NSRange,
                                 intent: CodeBlockCancellationIntent = .escape) -> EditPlan? {
        guard selection.length == 0, selection.location >= range.location,
              selection.location <= NSMaxRange(range),
              text.consistsOfLineBreaks else { return nil }
        if intent != .escape {
            let boundary = intent == .backwardDeletion ? range.location : NSMaxRange(range)
            guard selection.location == boundary else { return nil }
            return EditPlan(range: selection, original: "", conversion: .paragraph(.body))
        }
        return EditPlan(range: range, original: text, conversion: .paragraph(.body))
    }

    /// A paragraph owns the font at its first/last character (or separator).
    /// An empty paragraph with no character cannot borrow the previous font.
    public static func isCodeParagraph(_ paragraph: NSRange, fontIsCode: (Int) -> Bool?) -> Bool {
        codeParagraphState(paragraph, separatorIsCode: nil, fontIsCode: fontIsCode) == true
    }

    /// Native paragraph separators carry the paragraph format even when CJK or
    /// emoji glyphs use a fallback font that Accessibility cannot resolve.
    /// Unknown format is not a confirmed Body boundary.
    public static func codeParagraphState(_ paragraph: NSRange, separatorIsCode: Bool?,
                                          fontIsCode: (Int) -> Bool?) -> Bool? {
        guard paragraph.location >= 0, paragraph.length >= 0 else { return nil }
        if let separatorIsCode { return separatorIsCode }
        let first = fontIsCode(paragraph.location)
        guard paragraph.length > 0 else { return first }
        let last = fontIsCode(NSMaxRange(paragraph) - 1)
        if first == false || last == false { return false }
        return first == true && last == true ? true : nil
    }

    /// Classify a paragraph inside a sampled window. The empty paragraph at the
    /// end of the sample has no character of its own: it is Body only at the
    /// document end, and unknown when the document continues past the sample.
    public static func paragraphState(_ paragraph: NSRange, in source: NSString, endsAtDocumentBoundary: Bool,
                                      fontIsCode: (Int) -> Bool?) -> Bool? {
        // No separator or character exists for the empty terminal paragraph.
        // It cannot inherit the previous paragraph's code font.
        if paragraph.length == 0, paragraph.location == source.length { return endsAtDocumentBoundary ? false : nil }
        let end = NSMaxRange(paragraph)
        let hasSeparator = end < source.length && source.isLineBreak(at: end)
        return codeParagraphState(paragraph, separatorIsCode: hasSeparator ? fontIsCode(end) : nil, fontIsCode: fontIsCode)
    }

    /// A selection ending at the start of an empty paragraph may leave that
    /// paragraph unchanged. Apply Body at the terminal caret as well.
    public static func bodyFormattingSelections(for plan: EditPlan) -> [NSRange] {
        guard plan.conversion == .paragraph(.body),
              plan.original.consistsOfLineBreaks,
              plan.range.length == (plan.original as NSString).length else { return [] }
        return plan.range.length == 0 ? [plan.range] : [plan.range, NSRange(location: NSMaxRange(plan.range), length: 0)]
    }
}
