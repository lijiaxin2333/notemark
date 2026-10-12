import XCTest
@testable import NoteMarkCore

final class EventTapHealthTests: XCTestCase {
    func testThirdDisableWithinTheWindowStops() {
        var health = EventTapHealth()
        XCTAssertEqual(health.recordDisable(at: 100), .reenable)
        XCTAssertEqual(health.recordDisable(at: 110), .reenable)
        XCTAssertEqual(health.recordDisable(at: 120), .stop)
    }

    func testIsolatedDisablesOverALongSessionKeepReenabling() {
        var health = EventTapHealth()
        for minute in 0..<30 {
            XCTAssertEqual(health.recordDisable(at: TimeInterval(minute * 61)), .reenable, "\(minute)")
        }
    }

    func testResetForgetsEarlierDisables() {
        var health = EventTapHealth()
        _ = health.recordDisable(at: 1)
        _ = health.recordDisable(at: 2)
        health.reset()
        XCTAssertEqual(health.recordDisable(at: 3), .reenable)
    }
}
