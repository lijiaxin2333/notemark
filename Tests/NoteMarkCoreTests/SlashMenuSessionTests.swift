import XCTest
@testable import NoteMarkCore

final class SlashMenuSessionTests: XCTestCase {
    func testBareSlashOnlyOpensForFreshSlashInput() {
        var session = SlashMenuSession()
        XCTAssertEqual(session.update(beforeCaret: "/"), .hide)
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
        XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
    }

    func testTitleAndSubstringShowButBackspacingToSlashStaysHidden() {
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
        XCTAssertEqual(session.update(beforeCaret: "/标题"), .show("标题"))
        XCTAssertEqual(session.update(beforeCaret: "/标"), .show("标"))
        XCTAssertEqual(session.update(beforeCaret: "/"), .hide)
        XCTAssertEqual(session.update(beforeCaret: "/"), .hide)
        XCTAssertEqual(session.update(beforeCaret: "/题"), .show("题"))
        XCTAssertEqual(session.update(beforeCaret: "/"), .hide)
    }

    func testWhitespaceAndUnknownQueriesHideWithoutLosingSearchTracking() {
        for input in ["/ ", "/　", "／ ", "/空格", "/nothingmatches", "/usr/bin", "/hello world"] {
            var session = SlashMenuSession()
            session.begin()
            XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
            XCTAssertEqual(session.update(beforeCaret: input), .hide, input)
            XCTAssertEqual(session.update(beforeCaret: input), .hide, input)
            XCTAssertEqual(session.update(beforeCaret: "/"), .hide)
            XCTAssertEqual(session.update(beforeCaret: "/code"), .show("code"))
        }
    }

    func testEnglishNamesWithSpacesStayVisibleWhileTyped() {
        for (name, id) in [("code block", "monostyled"), ("bulleted list", "bullets"),
                           ("dashed list", "dashed"), ("numbered list", "numbered")] {
            var session = SlashMenuSession()
            session.begin()
            XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
            for length in 1...name.count {
                let typed = String(name.prefix(length))
                let expected = typed.trimmingCharacters(in: .whitespaces)
                XCTAssertEqual(session.update(beforeCaret: "/" + typed), .show(expected), typed)
                XCTAssertTrue(SlashCommand.matching(expected).contains { $0.id == id }, typed)
            }
            XCTAssertEqual(SlashCommand.matching(name).first?.id, id, name)
        }
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/code"), .show("code"))
        XCTAssertEqual(session.update(beforeCaret: "/code is fun"), .hide)
    }

    func testFastTypingAndBackspacingBeforeFirstRefreshDoesNotShowEmptyMenu() {
        var session = SlashMenuSession()
        session.begin()
        session.noteSearchInput()
        session.noteSearchInput(isDeletion: true)
        XCTAssertEqual(session.update(beforeCaret: "/"), .hide)
        session.begin()
        session.noteSearchInput()
        XCTAssertEqual(session.update(beforeCaret: "/ "), .hide)
    }

    func testNewlyTypedSlashCanOpenAgainAfterPreviousQueryWasHidden() {
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/title"), .show("title"))
        XCTAssertEqual(session.update(beforeCaret: "/"), .hide)
        XCTAssertEqual(session.update(beforeCaret: ""), .dismiss)
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
    }

    func testCompositionAfterHiddenSearchOnlyReopensForCommittedMatch() {
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
        XCTAssertEqual(session.update(beforeCaret: "/notacommand"), .hide)
        XCTAssertEqual(session.update(beforeCaret: "/biao'ti", isComposing: true), .wait)
        XCTAssertEqual(session.update(beforeCaret: "/标题"), .show("标题"))
        XCTAssertEqual(session.update(beforeCaret: "/题biao'ti", isComposing: true), .wait)
        XCTAssertEqual(session.update(beforeCaret: "/不存在"), .hide)
    }

    func testWeTypePinyinSelectionKeepsMenuUntilCandidateCommit() {
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
        // WeType exposes an apostrophe inside provisional pinyin and may select it.
        XCTAssertEqual(session.update(beforeCaret: "/biao'ti", afterCaret: "i", selectionLength: 2,
                                      isComposing: true), .wait)
        XCTAssertEqual(session.update(beforeCaret: nil, isComposing: true), .wait)
        // Candidate commit has no new slash keystroke; the ongoing session refreshes it.
        XCTAssertEqual(session.update(beforeCaret: "/标题"), .show("标题"))
        XCTAssertEqual(SlashCommand.matching("标题").first?.style, .title)
    }

    func testCompositionBeforeFirstDebouncedReadStillShowsMenu() {
        var session = SlashMenuSession()
        session.begin()
        session.noteSearchInput()
        XCTAssertEqual(session.update(beforeCaret: "/biao'ti", isComposing: true), .show(""))
        XCTAssertEqual(session.update(beforeCaret: "/标题 "), .show("标题"))
    }

    func testVisitingBareSlashInAnotherParagraphDoesNotOpenInitialMenu() {
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
        XCTAssertEqual(session.update(beforeCaret: "/\n/"), .hide)
        XCTAssertEqual(session.update(beforeCaret: "/\n/题"), .show("题"))
        XCTAssertEqual(session.update(beforeCaret: "/\n/"), .hide)
    }

    func testCompositionPreservesCommittedChineseQuery() {
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/小"), .show("小"))
        XCTAssertEqual(session.update(beforeCaret: "/小biao'ti", isComposing: true), .wait)
        XCTAssertEqual(session.update(beforeCaret: "/小标题"), .show("小标题"))
    }

    func testCandidateWindowClosesBeforeTextCommitIsPublished() {
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
        XCTAssertEqual(session.update(beforeCaret: "/biao'ti", isComposing: true), .wait)
        XCTAssertEqual(session.update(beforeCaret: "/biao'ti", selectionLength: 2), .wait)
        XCTAssertEqual(session.update(beforeCaret: "/biao'ti"), .wait)
        XCTAssertEqual(session.update(beforeCaret: "/标题"), .show("标题"))
    }

    func testCancelledCompositionWithInvalidTextEventuallyDismisses() {
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
        XCTAssertEqual(session.update(beforeCaret: "/biao'ti", isComposing: true), .wait)
        for _ in 0..<5 { XCTAssertEqual(session.update(beforeCaret: "/biao'ti"), .wait) }
        XCTAssertEqual(session.update(beforeCaret: "/biao'ti"), .hide)
    }

    func testSnapshotFailureRetriesAndRecoversWithoutNewKeystroke() {
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
        for _ in 0..<5 { XCTAssertEqual(session.update(beforeCaret: nil), .wait) }
        XCTAssertEqual(session.update(beforeCaret: "/title "), .show("title"))
        for _ in 0..<5 { XCTAssertEqual(session.update(beforeCaret: nil), .wait) }
        XCTAssertEqual(session.update(beforeCaret: nil), .dismiss)
    }

    func testLongCompositionDoesNotExhaustSnapshotRetries() {
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
        for _ in 0..<30 { XCTAssertEqual(session.update(beforeCaret: nil, isComposing: true), .wait) }
        XCTAssertEqual(session.update(beforeCaret: "/标题"), .show("标题"))
    }

    func testInvalidCommittedTextAndActualSelectionsDismiss() {
        for input in ["", "plain text", "/\n正文"] {
            var session = SlashMenuSession()
            session.begin()
            XCTAssertEqual(session.update(beforeCaret: "/"), .show(""))
            XCTAssertEqual(session.update(beforeCaret: input), .dismiss, input)
        }
        var session = SlashMenuSession()
        session.begin()
        XCTAssertEqual(session.update(beforeCaret: "/title", selectionLength: 2), .hide)
        XCTAssertEqual(session.update(beforeCaret: "/title", afterCaret: "text"), .hide)
        XCTAssertEqual(session.update(beforeCaret: "/title", isMonospaced: true, isComposing: true), .dismiss)
        XCTAssertEqual(session.update(beforeCaret: "look /", isComposing: true), .dismiss)
        XCTAssertEqual(session.update(beforeCaret: "/", windowStart: 5, isComposing: true), .dismiss)
    }

    func testFullWidthSlashAndUTF16ParagraphBoundaryDuringComposition() {
        var session = SlashMenuSession()
        session.begin()
        let prefix = "👩🏽‍💻\n"
        XCTAssertEqual(session.update(beforeCaret: prefix + "／biao'ti", windowStart: 100,
                                      isComposing: true), .show(""))
        XCTAssertEqual(session.paragraphStart, 100 + (prefix as NSString).length)
        XCTAssertEqual(session.update(beforeCaret: prefix + "／标题　", windowStart: 100), .show("标题"))
    }
}
