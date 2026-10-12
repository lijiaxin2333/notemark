import AppKit
import XCTest
@testable import NoteMarkCore

final class StyledTextSampleTests: XCTestCase {
    private func sample(_ text: String, start: Int = 0, documentLength: Int? = nil,
                        code: @escaping (Int) -> Bool?) -> StyledTextSample {
        let length = (text as NSString).length
        return StyledTextSample(range: NSRange(location: start, length: length), text: text,
                                documentLength: documentLength ?? start + length, fontIsCode: code)
    }

    func testLeadingParagraphUsesItsSeparatorFont() {
        // Chinese glyphs use an unknown fallback font; the code separator decides.
        let text = "中文\nbody"
        XCTAssertEqual(sample(text, code: { $0 == 2 ? true : nil }).leadingParagraphCodeState(), true)
        XCTAssertEqual(sample(text, code: { $0 == 2 ? false : true }).leadingParagraphCodeState(), false)
    }

    func testLeadingParagraphNeedsAnEndInsideTheSample() {
        XCTAssertNil(sample("code", documentLength: 100, code: { _ in true }).leadingParagraphCodeState())
        XCTAssertEqual(sample("code", code: { _ in true }).leadingParagraphCodeState(), true)
        XCTAssertEqual(sample("code\n", documentLength: 100, code: { _ in true }).leadingParagraphCodeState(), true)
    }

    func testUnterminatedParagraphSpansTheRequestedRange() {
        // If Notes returns less text than requested, fonts still classify the requested range.
        let short = StyledTextSample(range: NSRange(location: 10, length: 4), text: "co", documentLength: 14,
                                     fontIsCode: { $0 == 0 || $0 == 3 ? true : nil })
        XCTAssertEqual(short.leadingParagraphCodeState(), true)
    }

    func testEmptyTerminalParagraphIsBodyOnlyAtTheDocumentEnd() {
        XCTAssertEqual(sample("", start: 10, code: { _ in true }).leadingParagraphCodeState(), false)
    }

    func testCodeBlockMatchesTheEquivalentDirectRead() {
        let text = "body\n\n\nnext"
        let source = text as NSString
        let code: (Int) -> Bool? = { $0 >= 5 && $0 <= 6 }
        let direct = CodeBlockContext.read(text: text, windowStart: 20, documentLength: 20 + source.length,
            caret: 26, currentLineIsCode: true, isCodeLine: {
                CodeBlockContext.paragraphState($0, in: source, endsAtDocumentBoundary: true, fontIsCode: code)
            })
        let sampled = sample(text, start: 20, code: code).codeBlock(caret: 26)
        XCTAssertNotNil(sampled)
        XCTAssertEqual(sampled, direct)
        XCTAssertEqual(sampled?.range, NSRange(location: 25, length: 1))
        XCTAssertEqual(sampled?.text, "\n")
    }

    func testFontClassification() {
        let menlo = NSFont(name: "Menlo", size: 13)!
        XCTAssertEqual(NotesFont.codeState(of: [.font: menlo]), true)
        XCTAssertEqual(NotesFont.codeState(of: [.font: NSFont.systemFont(ofSize: 13)]), false)
        XCTAssertNil(NotesFont.codeState(of: [:]))
        if let fallback = NSFont(name: "PingFangSC-Regular", size: 13) {
            XCTAssertNil(NotesFont.codeState(of: [.font: fallback]))
        }
        let described: [NSAttributedString.Key: Any] = [
            NotesFont.accessibilityFontKey: ["AXFontName": "Menlo-Regular", "AXFontSize": 13],
            .foregroundColor: NSColor.red, .underlineStyle: 1
        ]
        XCTAssertEqual(NotesFont.codeState(of: described), true)
        let rendering = NotesFont.renderingAttributes(from: described)
        XCTAssertEqual((rendering?[.font] as? NSFont)?.fontName, "Menlo-Regular")
        XCTAssertEqual(rendering?[.foregroundColor] as? NSColor, .red)
        XCTAssertNil(rendering?[.underlineStyle])
        XCTAssertNil(NotesFont.font(in: [NotesFont.accessibilityFontKey: ["AXFontName": "Menlo", "AXFontSize": 0]]))
        let raw: [NSAttributedString.Key: Any] = [.font: menlo, .underlineStyle: 1]
        XCTAssertEqual(NotesFont.renderingAttributes(from: raw)?.count, 2)
    }
}
