import XCTest
@testable import QuickEmoji

final class PickerWindowTests: XCTestCase {
    func testNativeTextEditingIsUsedOnlyWhenPickerIsActiveAndKey() {
        XCTAssertTrue(
            PickerWindow.usesNativeTextEditing(
                isApplicationActive: true,
                isPickerKeyWindow: true
            )
        )
        XCTAssertFalse(
            PickerWindow.usesNativeTextEditing(
                isApplicationActive: false,
                isPickerKeyWindow: true
            )
        )
        XCTAssertFalse(
            PickerWindow.usesNativeTextEditing(
                isApplicationActive: true,
                isPickerKeyWindow: false
            )
        )
    }

    func testSelectAllShortcutRequiresOnlyCommandA() {
        XCTAssertTrue(
            PickerWindow.isSelectAllShortcut(
                charactersIgnoringModifiers: "a",
                flags: [.maskCommand]
            )
        )
        XCTAssertFalse(
            PickerWindow.isSelectAllShortcut(
                charactersIgnoringModifiers: "a",
                flags: [.maskCommand, .maskShift]
            )
        )
        XCTAssertFalse(
            PickerWindow.isSelectAllShortcut(
                charactersIgnoringModifiers: "q",
                flags: [.maskCommand]
            )
        )
    }
}
