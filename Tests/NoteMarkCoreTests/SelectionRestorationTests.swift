import XCTest
@testable import NoteMarkCore

@MainActor final class SelectionRestorationTests: XCTestCase {
    func testDelayedFormattingMovesCaretToBottomAndIsCorrectedBeforeInputResumes() async {
        let original = NSRange(location: 7, length: 0)
        let bottom = NSRange(location: 20, length: 0)
        var selection = bottom
        var ticks = 0
        var writes: [NSRange] = []
        let restored = await SelectionRestoration.restore(original, isValid: { true }, read: { selection }, write: {
            writes.append($0)
            selection = $0
            return true
        }, pause: {
            ticks += 1
            // The bulk-format command and terminal-paragraph command each
            // update selection after the immediate restoration already passed.
            if [2, 5].contains(ticks) { selection = bottom }
        })
        XCTAssertTrue(restored)
        XCTAssertEqual(selection, original)
        XCTAssertEqual(writes, [original, original, original])
        XCTAssertEqual(ticks, 8)
        // A queued Backspace now acts at the original caret, not block end.
        selection.location -= 1
        XCTAssertEqual(selection.location, 6)
    }

    func testImmediateReadbackDoesNotReleaseQueuedInputBeforeSettling() async {
        let caret = NSRange(location: 10, length: 0)
        var ticks = 0
        let restored = await SelectionRestoration.restore(caret, isValid: { true }, read: { caret },
            write: { _ in true }, pause: { ticks += 1 })
        XCTAssertTrue(restored)
        XCTAssertEqual(ticks, 6)
    }

    func testTransientSelectionWriteFailureIsRetried() async {
        let caret = NSRange(location: 7, length: 0)
        var selection = NSRange(location: 20, length: 0)
        var writes = 0
        let restored = await SelectionRestoration.restore(caret, isValid: { true }, read: { selection }, write: {
            writes += 1
            if writes < 3 { return false }
            selection = $0
            return true
        }, pause: {})
        XCTAssertTrue(restored)
        XCTAssertEqual(selection, caret)
        XCTAssertEqual(writes, 3)
    }

    func testPersistentFailureDoesNotReportSuccess() async {
        var ticks = 0
        let restored = await SelectionRestoration.restore(NSRange(location: 7, length: 0),
            isValid: { true }, read: { NSRange(location: 20, length: 0) }, write: { _ in false },
            pause: { ticks += 1 })
        XCTAssertFalse(restored)
        XCTAssertEqual(ticks, 15)
    }

    func testFocusChangeStopsWritingSelectionInAnotherEditor() async {
        var valid = true
        var writes = 0
        let restored = await SelectionRestoration.restore(NSRange(location: 7, length: 0),
            isValid: { valid }, read: { NSRange(location: 20, length: 0) }, write: { _ in
                writes += 1; return true
            }, pause: { valid = false })
        XCTAssertFalse(restored)
        XCTAssertEqual(writes, 1)
    }

    func testCancelledWaitDoesNotRetrySelection() async {
        var writes = 0
        let restored = await SelectionRestoration.restore(NSRange(location: 7, length: 0),
            isValid: { true }, read: { nil }, write: { _ in writes += 1; return true },
            pause: { throw CancellationError() })
        XCTAssertFalse(restored)
        XCTAssertEqual(writes, 1)
    }
}
