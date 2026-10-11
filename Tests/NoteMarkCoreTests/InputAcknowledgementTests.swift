import XCTest
@testable import NoteMarkCore

@MainActor final class InputAcknowledgementTests: XCTestCase {
    func testChecklistWaitsForClosingBracketToReachTheEditor() async {
        var pauses = 0
        let result = await InputAcknowledgement.wait(isValid: { true }, read: {
            MarkdownRule.plan(beforeCaret: pauses < 2 ? "[" : "[]", trigger: .space)
        }, pause: { pauses += 1 })
        XCTAssertEqual(result?.conversion, .paragraph(.checklist))
        XCTAssertEqual(result?.range, NSRange(location: 0, length: 2))
        XCTAssertEqual(pauses, 2)
    }

    func testUnmatchedInputStopsAtTheLimit() async {
        var pauses = 0
        let result: EditPlan? = await InputAcknowledgement.wait(isValid: { true }, read: {
            MarkdownRule.plan(beforeCaret: "hello]", trigger: .space)
        }, pause: { pauses += 1 })
        XCTAssertNil(result)
        XCTAssertEqual(pauses, 6)
    }

    func testFocusChangeOrStopDoesNotReadOrConvert() async {
        var valid = true
        var reads = 0
        let result: Int? = await InputAcknowledgement.wait(isValid: { valid }, read: {
            reads += 1
            return 1
        }, pause: { valid = false })
        XCTAssertNil(result)
        XCTAssertEqual(reads, 0)
    }

    func testFocusChangeDuringReadDiscardsTheResult() async {
        var valid = true
        let result: Int? = await InputAcknowledgement.wait(attempts: 1, isValid: { valid }, read: {
            valid = false
            return 1
        }, pause: {})
        XCTAssertNil(result)
    }

    func testCancelledPauseDoesNotReadOrConvert() async {
        var reads = 0
        let result: Int? = await InputAcknowledgement.wait(isValid: { true }, read: {
            reads += 1
            return 1
        }, pause: { throw CancellationError() })
        XCTAssertNil(result)
        XCTAssertEqual(reads, 0)
    }
}
