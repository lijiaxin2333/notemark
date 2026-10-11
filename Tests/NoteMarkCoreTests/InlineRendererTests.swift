import AppKit
import XCTest
@testable import NoteMarkCore

final class InlineRendererTests: XCTestCase {
    func testNoFontNeverInventsACustomSize() {
        XCTAssertNil(InlineRenderer.render(style: .bold, text: "test", delimiter: " ", attributes: [:]))
    }
    func testStylesPreserveCurrentPointSize() throws {
        for size: CGFloat in [13.0, 17.0, 22.0] {
            let font = NSFont.systemFont(ofSize: size)
            for style in [InlineStyle.bold, .italic, .boldItalic, .code, .strike] {
                let value = try XCTUnwrap(InlineRenderer.render(style: style, text: "中文🌳", delimiter: " ", attributes: [.font: font]))
                XCTAssertEqual((value.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, size)
                XCTAssertEqual(value.string, "中文🌳 ")
                XCTAssertEqual(value.attribute(.font, at: value.length - 1, effectiveRange: nil) as? NSFont, font)
                XCTAssertNil(value.attribute(.strikethroughStyle, at: value.length - 1, effectiveRange: nil))
            }
        }
    }
    func testRTFRoundTripPreservesUnicodeAndFontSize() throws {
        let value = try XCTUnwrap(InlineRenderer.render(style: .code, text: "let 🌳 = 1", delimiter: "\n", attributes: [.font: NSFont.systemFont(ofSize: 17)]))
        let data = try value.data(from: NSRange(location: 0, length: value.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let restored = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        XCTAssertEqual(restored.string, value.string)
        XCTAssertEqual((restored.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 17)
        XCTAssertEqual((restored.attribute(.font, at: restored.length - 1, effectiveRange: nil) as? NSFont)?.pointSize, 17)
    }
    func testLinkDoesNotContinueIntoSeparator() throws {
        let value = try XCTUnwrap(InlineRenderer.render(style: .link("https://example.com"), text: "链接", delimiter: " ", attributes: [.font: NSFont.systemFont(ofSize: 13)]))
        XCTAssertEqual(value.attribute(.link, at: 0, effectiveRange: nil) as? URL, URL(string: "https://example.com"))
        XCTAssertNil(value.attribute(.link, at: value.length - 1, effectiveRange: nil))
    }
    func testExistingColorAndParagraphArePreserved() throws {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.red, .paragraphStyle: paragraph]
        let value = try XCTUnwrap(InlineRenderer.render(style: .bold, text: "文字", delimiter: " ", attributes: attributes))
        XCTAssertEqual(value.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .red)
        XCTAssertEqual((value.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.alignment, .center)
    }
}
