import XCTest
@testable import NoteMarkCore

final class AutomaticConversionPolicyTests: XCTestCase {
    private let ready = ConversionPermissions(accessibility: true, inputMonitoring: true)
    private let missing = ConversionPermissions(accessibility: false, inputMonitoring: false)

    func testConfiguredLaunchStartsWithoutUserAction() {
        var policy = AutomaticConversionPolicy()
        XCTAssertTrue(policy.shouldStart(permissions: ready, running: false))
        XCTAssertFalse(policy.shouldStart(permissions: ready, running: true))
    }

    func testGrantingPermissionsDuringRunStartsAutomatically() {
        var policy = AutomaticConversionPolicy()
        XCTAssertFalse(policy.shouldStart(permissions: missing, running: false))
        XCTAssertTrue(policy.shouldStart(permissions: ready, running: false))
    }

    func testFailedTapRetriesOnlyAfterPermissionChange() {
        var policy = AutomaticConversionPolicy()
        let accessibilityOnly = ConversionPermissions(accessibility: true, inputMonitoring: false)
        XCTAssertTrue(policy.shouldStart(permissions: accessibilityOnly, running: false))
        XCTAssertFalse(policy.shouldStart(permissions: accessibilityOnly, running: false))
        XCTAssertTrue(policy.shouldStart(permissions: ready, running: false))
    }

    func testExplicitPauseSurvivesPollingAndPermissionChanges() {
        var policy = AutomaticConversionPolicy()
        XCTAssertTrue(policy.shouldStart(permissions: ready, running: false))
        policy.pause()
        XCTAssertFalse(policy.shouldStart(permissions: ready, running: false))
        XCTAssertFalse(policy.shouldStart(permissions: missing, running: false))
        XCTAssertFalse(policy.shouldStart(permissions: ready, running: false))
        policy.resume()
        XCTAssertTrue(policy.shouldStart(permissions: ready, running: false))
    }

    func testRevocationAndRegrantAllowAutomaticRecovery() {
        var policy = AutomaticConversionPolicy()
        XCTAssertTrue(policy.shouldStart(permissions: ready, running: false))
        XCTAssertFalse(policy.shouldStart(permissions: missing, running: true))
        XCTAssertTrue(policy.shouldStart(permissions: ready, running: false))
    }

    func testNewLaunchDoesNotPersistSessionPause() {
        var oldSession = AutomaticConversionPolicy()
        oldSession.pause()
        var newSession = AutomaticConversionPolicy()
        XCTAssertTrue(newSession.shouldStart(permissions: ready, running: false))
    }
}
