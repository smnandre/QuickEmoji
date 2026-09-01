import AppKit
import XCTest
@testable import QuickEmoji

final class PanelGeometryTests: XCTestCase {
    func testPickerDefaultFrameIsCenteredAndNearThirtyPercentFromTop() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let size = CGSize(width: 400, height: 300)

        let frame = PanelGeometry.pickerDefaultFrame(size: size, in: visibleFrame)

        XCTAssertEqual(frame.midX, 500, accuracy: 0.001)
        XCTAssertEqual(frame.midY, 560, accuracy: 0.001)
    }

    func testOffscreenSavedFrameIsRejected() {
        let visibleFrames = [CGRect(x: 0, y: 0, width: 1000, height: 800)]
        let frame = CGRect(
            x: 1800,
            y: 1800,
            width: PickerGeometry.defaultSize.width,
            height: PickerGeometry.defaultSize.height
        )

        XCTAssertFalse(PanelGeometry.isUsableSavedFrame(frame, visibleFrames: visibleFrames))
    }

    func testUsableSavedFrameIsAccepted() {
        let visibleFrames = [CGRect(x: 0, y: 0, width: 1000, height: 800)]
        let frame = CGRect(
            x: 280,
            y: 220,
            width: PickerGeometry.defaultSize.width,
            height: PickerGeometry.defaultSize.height
        )

        XCTAssertTrue(PanelGeometry.isUsableSavedFrame(frame, visibleFrames: visibleFrames))
    }

    func testPickerGeometryUsesFiveColumnsAndTwoRows() {
        XCTAssertEqual(PickerGeometry.visibleColumnLimit, 5)
        XCTAssertEqual(PickerGeometry.visibleRowLimit, 2)
        XCTAssertEqual(PickerGeometry.defaultSize.width, 298)
        XCTAssertEqual(PickerGeometry.defaultSize.height, 190)
    }
}
