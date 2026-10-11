import XCTest
@testable import NoteMarkCore

final class EmptyParagraphCancellationTests: XCTestCase {
    func testExistingCodeABCDeletedAfterFocusChangeCanCancelWithoutCreationToken() {
        // The app has restarted or the user has clicked back into an existing code line.
        let before = "title\nabc"
        let recovered = EmptyParagraphCancellation.recoverCode(beforeCaret: before, windowStart: 0,
            selection: NSRange(location: 9, length: 0), isMonospacedParagraph: true)!
        for text in ["ab", "a"] {
            XCTAssertNil(recovered.plan(beforeCaret: "title\n" + text, windowStart: 0, afterCaret: "",
                selection: NSRange(location: 6 + text.count, length: 0)))
        }
        let plan = recovered.plan(beforeCaret: "title\n", windowStart: 0, afterCaret: "",
                                  selection: NSRange(location: 6, length: 0))
        XCTAssertEqual(plan?.conversion, .paragraph(.body))
        XCTAssertEqual(plan?.range, NSRange(location: 6, length: 0))
    }

    func testRecoverBeforeLastDeletionThenCancelOnNextKey() {
        let recovered = EmptyParagraphCancellation.recoverCode(beforeCaret: "a", windowStart: 0,
            selection: NSRange(location: 1, length: 0), isMonospacedParagraph: true)!
        XCTAssertNil(recovered.plan(beforeCaret: "a", windowStart: 0, afterCaret: "",
            selection: NSRange(location: 1, length: 0)))
        XCTAssertEqual(recovered.plan(beforeCaret: "", windowStart: 0, afterCaret: "",
            selection: NSRange(location: 0, length: 0))?.conversion, .paragraph(.body))
    }

    func testRecoveryDoesNotGuessEmptyBodyFromPreviousCodeLine() {
        XCTAssertNil(EmptyParagraphCancellation.recoverCode(beforeCaret: "code\n", windowStart: 0,
            selection: NSRange(location: 5, length: 0), isMonospacedParagraph: true))
        XCTAssertNil(EmptyParagraphCancellation.recoverCode(beforeCaret: "prose", windowStart: 0,
            selection: NSRange(location: 5, length: 0), isMonospacedParagraph: false))
    }

    func testEmptyCodeRecoversAfterTrackingLossAndBodyCharacterBeforeCaret() {
        // Real diagnostic: preceding character is Body, current empty line is
        // monospaced, but cancellation tracking was already cleared.
        for blankLines in [1, 2, 10, 100] {
            let before = "body" + String(repeating: "\n", count: blankLines)
            let caret = (before as NSString).length
            let recovered = EmptyParagraphCancellation.recoverCode(beforeCaret: before, windowStart: 0,
                selection: NSRange(location: caret, length: 0), isMonospacedParagraph: false,
                isEmptyMonospacedParagraph: true)
            XCTAssertEqual(recovered?.paragraphStart, caret)
            XCTAssertEqual(recovered?.plan(beforeCaret: before, windowStart: 0, afterCaret: "\n",
                selection: NSRange(location: caret, length: 0))?.conversion, .paragraph(.body))
        }
    }

    func testEmptyCodeRecoveryFollowsRepeatedNativeNewlineDeletions() {
        for count in (0...20).reversed() {
            let before = String(repeating: "\n", count: count)
            XCTAssertNotNil(EmptyParagraphCancellation.recoverCode(beforeCaret: before, windowStart: 0,
                selection: NSRange(location: count, length: 0), isMonospacedParagraph: false,
                isEmptyMonospacedParagraph: true))
        }
        // Empty-paragraph evidence must not arm a nonempty Body line.
        XCTAssertNil(EmptyParagraphCancellation.recoverCode(beforeCaret: "body", windowStart: 0,
            selection: NSRange(location: 4, length: 0), isMonospacedParagraph: false,
            isEmptyMonospacedParagraph: true))
        XCTAssertNil(EmptyParagraphCancellation.recoverCode(beforeCaret: "", windowStart: 10,
            selection: NSRange(location: 10, length: 0), isMonospacedParagraph: false,
            isEmptyMonospacedParagraph: true))
    }

    func testRecoveryRejectsSelectionsImagesAndUnknownBoundaries() {
        XCTAssertNil(EmptyParagraphCancellation.recoverCode(beforeCaret: "abc", windowStart: 0,
            selection: NSRange(location: 3, length: 1), isMonospacedParagraph: true))
        XCTAssertNil(EmptyParagraphCancellation.recoverCode(beforeCaret: "a\u{fffc}", windowStart: 0,
            selection: NSRange(location: 2, length: 0), isMonospacedParagraph: true))
        XCTAssertNil(EmptyParagraphCancellation.recoverCode(beforeCaret: "abc", windowStart: 10,
            selection: NSRange(location: 13, length: 0), isMonospacedParagraph: true))
    }

    func testCodeReturnAndDeletionAcrossLinesRestoreBodyOnOriginalLine() {
        let original = EmptyParagraphCancellation(style: .monostyled, paragraphStart: 7)!
        let before = "before\nfirst\nsecond"
        let secondLine = original.followingCodeCaret(beforeCaret: before, windowStart: 0,
            selection: NSRange(location: (before as NSString).length, length: 0), isMonospaced: true)!
        XCTAssertNil(secondLine.plan(beforeCaret: before, windowStart: 0, afterCaret: "",
                                     selection: NSRange(location: (before as NSString).length, length: 0)))

        // Delete the second line and its newline, then the first line's text.
        let firstLine = secondLine.followingCodeCaret(beforeCaret: "before\nfirst", windowStart: 0,
            selection: NSRange(location: 12, length: 0), isMonospaced: true)!
        let plan = firstLine.plan(beforeCaret: "before\n", windowStart: 0, afterCaret: "",
                                  selection: NSRange(location: 7, length: 0))
        XCTAssertEqual(plan?.conversion, .paragraph(.body))
        XCTAssertEqual(plan?.range, NSRange(location: 7, length: 0))
        XCTAssertEqual(plan?.original, "")
    }

    func testEmptyCodeLineAfterReturnCanBeCancelledImmediately() {
        let original = EmptyParagraphCancellation(style: .monostyled, paragraphStart: 7)!
        let before = "before\n\n"
        let following = original.followingCodeCaret(beforeCaret: before, windowStart: 0,
            selection: NSRange(location: 8, length: 0), isMonospaced: true)!
        XCTAssertEqual(following.plan(beforeCaret: before, windowStart: 0, afterCaret: "",
            selection: NSRange(location: 8, length: 0))?.conversion, .paragraph(.body))
        XCTAssertNil(following.plan(beforeCaret: before, windowStart: 0, afterCaret: "remaining code",
            selection: NSRange(location: 8, length: 0)))
    }

    func testFollowingCodeDoesNotTrackBodyOrOtherFormatsAcrossParagraphs() {
        for style in ParagraphStyle.allCases where style != .body {
            let session = EmptyParagraphCancellation(style: style, paragraphStart: 0)!
            XCTAssertNil(session.followingCodeCaret(beforeCaret: "code\n", windowStart: 0,
                selection: NSRange(location: 5, length: 0), isMonospaced: false), style.rawValue)
            if style != .monostyled {
                XCTAssertNil(session.followingCodeCaret(beforeCaret: "code\n", windowStart: 0,
                    selection: NSRange(location: 5, length: 0), isMonospaced: true), style.rawValue)
            }
        }
    }

    func testFollowingCodeRequiresConsistentKnownUTF16Boundary() {
        let original = EmptyParagraphCancellation(style: .monostyled, paragraphStart: 0)!
        XCTAssertNil(original.followingCodeCaret(beforeCaret: "", windowStart: 20,
            selection: NSRange(location: 20, length: 0), isMonospaced: true))
        XCTAssertNil(original.followingCodeCaret(beforeCaret: "x\n", windowStart: 10,
            selection: NSRange(location: 10, length: 0), isMonospaced: true))
        let before = "🌳\n中文\n"
        let start = (before as NSString).length
        let following = original.followingCodeCaret(beforeCaret: before, windowStart: 10,
            selection: NSRange(location: 10 + start, length: 0), isMonospaced: true)!
        XCTAssertEqual(following.plan(beforeCaret: before, windowStart: 10, afterCaret: "",
            selection: NSRange(location: 10 + start, length: 0))?.range, NSRange(location: 10 + start, length: 0))
    }

    func testEveryNonBodyParagraphStyleCanBeArmed() {
        for style in ParagraphStyle.allCases {
            XCTAssertEqual(EmptyParagraphCancellation(style: style, paragraphStart: 0) != nil,
                           style != .body, style.rawValue)
        }
        XCTAssertNil(EmptyParagraphCancellation(style: .title, paragraphStart: -1))
    }

    func testAllFormatsRestoreBodyWithoutDeletingTheEmptyParagraph() {
        for style in ParagraphStyle.allCases where style != .body {
            let cancellation = EmptyParagraphCancellation(style: style, paragraphStart: 7)!
            XCTAssertEqual(cancellation.style, style)
            let plan = cancellation.plan(beforeCaret: "before\n", windowStart: 0, afterCaret: "\nnext",
                                         selection: NSRange(location: 7, length: 0))
            XCTAssertEqual(plan?.conversion, .paragraph(.body), style.rawValue)
            XCTAssertEqual(plan?.range, NSRange(location: 7, length: 0), style.rawValue)
            XCTAssertEqual(plan?.original, "", style.rawValue)
        }
    }

    func testTypingThenDeletingContentKeepsCancellationAvailable() {
        for marker in ["#", "##", "###", ">", "```", "-", "*", "1.", "[]"] {
            guard let conversion = MarkdownRule.plan(beforeCaret: "prior\n" + marker, trigger: .space),
                  case .paragraph(let style) = conversion.conversion,
                  let cancellation = EmptyParagraphCancellation(style: style, paragraphStart: conversion.range.location) else {
                XCTFail("Missing cancellation for \(marker)"); continue
            }
            for content in ["中文🌳", "中文", "中", ""] {
                let before = "prior\n" + content
                let selection = NSRange(location: (before as NSString).length, length: 0)
                XCTAssertTrue(cancellation.containsCaret(beforeCaret: before, windowStart: 0, selection: selection) == true, marker)
                let plan = cancellation.plan(beforeCaret: before, windowStart: 0, afterCaret: "", selection: selection)
                XCTAssertEqual(plan != nil, content.isEmpty, marker)
            }
        }
    }

    func testMovementInsideParagraphKeepsSessionButLeavingItDoesNot() {
        let cancellation = EmptyParagraphCancellation(style: .monostyled, paragraphStart: 6)!
        for before in ["prior\n", "prior\nco", "prior\ncode"] {
            XCTAssertTrue(cancellation.containsCaret(beforeCaret: before, windowStart: 0,
                                                     selection: NSRange(location: (before as NSString).length, length: 0)) == true)
        }
        for before in ["prior", "prior\ncode\n", "prior\ncode\nnext"] {
            XCTAssertEqual(cancellation.containsCaret(beforeCaret: before, windowStart: 0,
                                                      selection: NSRange(location: (before as NSString).length, length: 0)), false)
        }
    }

    func testLongParagraphWindowDoesNotProveThatTheCaretLeft() {
        let cancellation = EmptyParagraphCancellation(style: .monostyled, paragraphStart: 6)!
        let sample = String(repeating: "a", count: 512)
        XCTAssertNil(cancellation.containsCaret(beforeCaret: sample, windowStart: 94,
                                                selection: NSRange(location: 606, length: 0)))
        XCTAssertEqual(cancellation.containsCaret(beforeCaret: "prior\n", windowStart: 0,
                                                  selection: NSRange(location: 6, length: 0)), true)
        XCTAssertNotNil(cancellation.plan(beforeCaret: "prior\n", windowStart: 0, afterCaret: "",
                                          selection: NSRange(location: 6, length: 0)))
    }

    func testSelectingContentAllowsDeletionButCannotCancelUntilEmpty() {
        let cancellation = EmptyParagraphCancellation(style: .quote, paragraphStart: 2)!
        let selection = NSRange(location: 2, length: 4)
        XCTAssertEqual(cancellation.containsCaret(beforeCaret: "x\n", windowStart: 0, selection: selection), true)
        XCTAssertNil(cancellation.plan(beforeCaret: "x\n", windowStart: 0, afterCaret: "text", selection: selection))
        XCTAssertNotNil(cancellation.plan(beforeCaret: "x\n", windowStart: 0, afterCaret: "",
                                          selection: NSRange(location: 2, length: 0)))
    }

    func testTrackingRejectsUnknownAndInconsistentBoundaries() {
        let cancellation = EmptyParagraphCancellation(style: .numbered, paragraphStart: 10)!
        XCTAssertNil(cancellation.containsCaret(beforeCaret: "", windowStart: 10,
                                                  selection: NSRange(location: 10, length: 0)))
        XCTAssertNil(cancellation.containsCaret(beforeCaret: "x\n", windowStart: 0,
                                                  selection: NSRange(location: 10, length: 0)))
        XCTAssertEqual(cancellation.containsCaret(beforeCaret: "x\n", windowStart: 8,
                                                 selection: NSRange(location: 10, length: 0)), true)
    }

    func testEmptyFirstLineRestoresBodyWithoutDeletingText() {
        let plan = EmptyParagraphCancellation(style: .title, paragraphStart: 0)?.plan(
            beforeCaret: "", windowStart: 0, afterCaret: "", selection: NSRange(location: 0, length: 0))
        XCTAssertEqual(plan?.conversion, .paragraph(.body))
        XCTAssertEqual(plan?.range, NSRange(location: 0, length: 0))
        XCTAssertEqual(plan?.original, "")
    }

    func testPreviousTextAndImageStayOutsideTheEdit() {
        let before = "🌳\u{fffc}\n"
        let start = (before as NSString).length
        let plan = EmptyParagraphCancellation(style: .heading, paragraphStart: start)?.plan(
            beforeCaret: before, windowStart: 0, afterCaret: "\n", selection: NSRange(location: start, length: 0))
        XCTAssertEqual(plan?.range, NSRange(location: start, length: 0))
    }

    func testKnownWindowBoundaryIsRequired() {
        let cancellation = EmptyParagraphCancellation(style: .title, paragraphStart: 10)!
        XCTAssertNil(cancellation.plan(beforeCaret: "", windowStart: 10, afterCaret: "",
                                        selection: NSRange(location: 10, length: 0)))
        XCTAssertNotNil(cancellation.plan(beforeCaret: "x\n", windowStart: 8, afterCaret: "",
                                           selection: NSRange(location: 10, length: 0)))
    }

    func testContentAndWhitespaceAreNotEmpty() {
        for content in ["a", " ", "\t", "中文", "🌳", "\u{fffc}"] {
            XCTAssertNil(EmptyParagraphCancellation(style: .title, paragraphStart: 0)?.plan(
                beforeCaret: content, windowStart: 0, afterCaret: "",
                selection: NSRange(location: (content as NSString).length, length: 0)), content)
        }
    }

    func testContentAfterCaretAndUnknownBoundaryAreRejected() {
        for after in ["text", " ", "\u{fffc}", "?"] {
            XCTAssertNil(EmptyParagraphCancellation(style: .title, paragraphStart: 0)?.plan(
                beforeCaret: "", windowStart: 0, afterCaret: after,
                selection: NSRange(location: 0, length: 0)), after)
        }
    }

    func testSelectionAndAnotherParagraphAreRejected() {
        let cancellation = EmptyParagraphCancellation(style: .title, paragraphStart: 0)!
        XCTAssertNil(cancellation.plan(beforeCaret: "", windowStart: 0, afterCaret: "",
                                        selection: NSRange(location: 0, length: 1)))
        XCTAssertNil(cancellation.plan(beforeCaret: "\n", windowStart: 0, afterCaret: "",
                                        selection: NSRange(location: 1, length: 0)))
    }

    func testInconsistentSnapshotIsRejected() {
        let cancellation = EmptyParagraphCancellation(style: .title, paragraphStart: 0)!
        XCTAssertNil(cancellation.plan(beforeCaret: "", windowStart: -1, afterCaret: "",
                                        selection: NSRange(location: 0, length: 0)))
        XCTAssertNil(cancellation.plan(beforeCaret: "x\n", windowStart: 0, afterCaret: "",
                                        selection: NSRange(location: 0, length: 0)))
    }
}
