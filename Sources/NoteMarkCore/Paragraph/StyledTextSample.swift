import Foundation

/// Editor text sampled together with per-character code-font evidence.
public struct StyledTextSample {
    /// Document range of the sample, in UTF-16 units.
    public let range: NSRange
    public let text: String
    public let documentLength: Int
    /// Code-font evidence at a UTF-16 offset relative to the sample start;
    /// nil when the font cannot classify the paragraph.
    public let fontIsCode: (Int) -> Bool?

    public init(range: NSRange, text: String, documentLength: Int, fontIsCode: @escaping (Int) -> Bool?) {
        self.range = range
        self.text = text
        self.documentLength = documentLength
        self.fontIsCode = fontIsCode
    }

    public var reachesDocumentEnd: Bool { NSMaxRange(range) == documentLength }

    /// Code state of the paragraph that begins at the sample start. Unknown
    /// unless that paragraph ends inside the sample or at the document end.
    /// Without a line break, the paragraph spans the whole sampled range.
    public func leadingParagraphCodeState() -> Bool? {
        let head = text.prefixBeforeLineBreak()
        guard head.foundLineBreak || reachesDocumentEnd else { return nil }
        let paragraph = NSRange(location: 0, length: head.foundLineBreak ? (head.text as NSString).length : range.length)
        return CodeBlockContext.paragraphState(paragraph, in: text as NSString, endsAtDocumentBoundary: reachesDocumentEnd,
                                               fontIsCode: fontIsCode)
    }

    /// The contiguous code paragraphs around `caret`, a document offset.
    public func codeBlock(caret: Int) -> CodeBlockContext? {
        let source = text as NSString
        let endsAtDocumentBoundary = reachesDocumentEnd
        let fontIsCode = fontIsCode
        return CodeBlockContext.read(text: text, windowStart: range.location, documentLength: documentLength,
                                     caret: caret, currentLineIsCode: true, isCodeLine: { paragraph in
            CodeBlockContext.paragraphState(paragraph, in: source, endsAtDocumentBoundary: endsAtDocumentBoundary,
                                            fontIsCode: fontIsCode)
        })
    }
}
