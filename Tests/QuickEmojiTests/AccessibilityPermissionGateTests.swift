import XCTest
@testable import QuickEmoji

final class AccessibilityPermissionGateTests: XCTestCase {
    func testGateRegistersOnceWhenPermissionBecomesTrusted() {
        var gate = AccessibilityPermissionGate()

        XCTAssertFalse(gate.shouldRegisterEventTap(isTrusted: false))
        XCTAssertTrue(gate.shouldRegisterEventTap(isTrusted: true))
        XCTAssertFalse(gate.shouldRegisterEventTap(isTrusted: true))
    }

    func testGateAllowsRegistrationAgainAfterPermissionMissing() {
        var gate = AccessibilityPermissionGate()

        XCTAssertTrue(gate.shouldRegisterEventTap(isTrusted: true))
        gate.resetIfPermissionMissing(isTrusted: false)

        XCTAssertTrue(gate.shouldRegisterEventTap(isTrusted: true))
    }

    func testGateAllowsRetryAfterRegistrationFailure() {
        var gate = AccessibilityPermissionGate()

        XCTAssertTrue(gate.shouldRegisterEventTap(isTrusted: true))
        gate.resetAfterRegistrationFailure()

        XCTAssertTrue(gate.shouldRegisterEventTap(isTrusted: true))
    }
}
