import XCTest
@testable import NoteMarkCore

final class NotesSubstitutionTests: XCTestCase {
    private func changes(off wanted: Set<NotesSubstitution>, turnedOff: Set<NotesSubstitution> = [],
                         states: [NotesSubstitution: Bool?]) -> NotesSubstitutionChanges {
        NotesSubstitutionChanges(keepingOff: wanted, turnedOffByNoteMark: turnedOff, isOn: { states[$0] ?? nil })
    }

    func testDashesAndListsAreTurnedOffByDefaultButTagsAreNot() {
        XCTAssertEqual(NotesSubstitution.turnedOffByDefault, [.smartDashes, .smartLists])
        let result = changes(off: NotesSubstitution.turnedOffByDefault,
                             states: [.smartDashes: true, .smartLists: true, .smartTags: true])
        XCTAssertEqual(result.turnOff, [.smartDashes, .smartLists])
        XCTAssertEqual(result.turnOn, [])
    }

    func testItemsAlreadyOffAreLeftAlone() {
        let result = changes(off: [.smartDashes, .smartLists], states: [.smartDashes: false, .smartLists: false, .smartTags: true])
        XCTAssertEqual(result, changes(off: [], states: [:]))
    }

    func testOnlyItemsNoteMarkTurnedOffAreTurnedBackOn() {
        let result = changes(off: [.smartDashes], turnedOff: [.smartDashes, .smartLists],
                             states: [.smartDashes: false, .smartLists: false, .smartTags: false])
        XCTAssertEqual(result.turnOff, [])
        XCTAssertEqual(result.turnOn, [.smartLists])
        // The user's own choice in Notes is never changed.
        XCTAssertEqual(changes(off: [], states: [.smartTags: false]).turnOn, [])
    }

    func testItemsTheUserTurnedOnAgainAreForgotten() {
        let result = changes(off: [], turnedOff: [.smartLists], states: [.smartLists: true])
        XCTAssertEqual(result.forget, [.smartLists])
        XCTAssertEqual(result.turnOn, [])
    }

    func testUnavailableItemsWait() {
        let result = changes(off: [.smartDashes], turnedOff: [.smartLists], states: [.smartDashes: nil, .smartLists: nil])
        XCTAssertEqual(result.turnOff, [])
        XCTAssertEqual(result.turnOn, [])
        XCTAssertEqual(result.forget, [])
    }
}
