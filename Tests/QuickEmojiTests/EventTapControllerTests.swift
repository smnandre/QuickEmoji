import Carbon.HIToolbox
import XCTest
@testable import QuickEmoji

final class EventTapControllerTests: XCTestCase {
    func testCommandShiftEIsTheHotKey() {
        XCTAssertTrue(
            EventTapController.isHotKey(
                keyCode: kVK_ANSI_E,
                flags: [.maskCommand, .maskShift]
            ))
    }

    func testControlAndOptionRejectTheHotKey() {
        XCTAssertFalse(
            EventTapController.isHotKey(
                keyCode: kVK_ANSI_E,
                flags: [.maskCommand, .maskShift, .maskControl]
            ))
        XCTAssertFalse(
            EventTapController.isHotKey(
                keyCode: kVK_ANSI_E,
                flags: [.maskCommand, .maskShift, .maskAlternate]
            ))
    }

    func testUnrelatedKeyIsNotTheHotKey() {
        XCTAssertFalse(
            EventTapController.isHotKey(
                keyCode: kVK_ANSI_F,
                flags: [.maskCommand, .maskShift]
            ))
    }
}
