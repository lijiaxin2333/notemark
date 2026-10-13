import Carbon.HIToolbox
import XCTest
@testable import NoteMarkCore

final class AttachmentInsertionTests: XCTestCase {
    func testInsertedRangeEndsAtTheCaret() {
        XCTAssertEqual(AttachmentInsertion.insertedRange(from: 10, to: 12, caret: 7, limit: 4096), NSRange(location: 5, length: 2))
        // Text typed after the paste is included, so the image is still found.
        XCTAssertEqual(AttachmentInsertion.insertedRange(from: 10, to: 15, caret: 15, limit: 4096), NSRange(location: 10, length: 5))
        XCTAssertEqual(AttachmentInsertion.insertedRange(from: 0, to: 10_000, caret: 9_000, limit: 4096), NSRange(location: 4904, length: 4096))
        XCTAssertEqual(AttachmentInsertion.insertedRange(from: 0, to: 5, caret: 2, limit: 4096), NSRange(location: 0, length: 2))
    }

    func testNoRangeWhenTheNoteDidNotGrow() {
        XCTAssertNil(AttachmentInsertion.insertedRange(from: 10, to: 10, caret: 5, limit: 4096))
        XCTAssertNil(AttachmentInsertion.insertedRange(from: 10, to: 8, caret: 5, limit: 4096))
        XCTAssertNil(AttachmentInsertion.insertedRange(from: 10, to: 12, caret: 0, limit: 4096))
    }

    func testAttachmentsAreFound() {
        XCTAssertTrue(AttachmentInsertion.containsAttachment("说明\u{fffc}\n"))
        XCTAssertFalse(AttachmentInsertion.containsAttachment("pasted text"))
    }

    func testOnlyCommandVCanPasteImages() {
        XCTAssertTrue(KeyPress(code: kVK_ANSI_V, modifiers: .command, layoutCharacter: "v").isPaste)
        // Dvorak types "v" on the ANSI period key.
        XCTAssertTrue(KeyPress(code: kVK_ANSI_Period, modifiers: .command, layoutCharacter: "v").isPaste)
        XCTAssertFalse(KeyPress(code: kVK_ANSI_V, modifiers: [.command, .option, .shift], layoutCharacter: "v").isPaste)
        XCTAssertFalse(KeyPress(code: kVK_ANSI_V, layoutCharacter: "v").isPaste)
    }
}
