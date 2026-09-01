import AppKit
import XCTest
@testable import QuickEmoji

@MainActor
final class PickerViewModelTests: XCTestCase {
    func testSelectionMovesByArrowIntentAndClamps() {
        let model = PickerViewModel(
            bundleID: "tests",
            compact: false,
            onSelect: { _, _ in },
            onDismiss: {}
        )
        model.results = (0..<10).map { index in
            PickerEntry(
                id: "entry-\(index)",
                character: "\(index)",
                name: "Entry \(index)",
                shortcode: "entry_\(index)",
                keywords: [],
                category: "tests"
            )
        }
        model.columnCount = 4

        model.selectedIndex = 5
        model.moveLeft()
        XCTAssertEqual(model.selectedIndex, 4)

        model.moveRight()
        XCTAssertEqual(model.selectedIndex, 5)

        model.moveUp()
        XCTAssertEqual(model.selectedIndex, 1)

        model.moveDown()
        XCTAssertEqual(model.selectedIndex, 5)

        model.selectedIndex = 0
        model.moveUp()
        XCTAssertEqual(model.selectedIndex, 0)

        model.selectedIndex = 9
        model.moveDown()
        XCTAssertEqual(model.selectedIndex, 9)
    }

    func testColumnCountUsesWidthWithLowerBound() {
        XCTAssertEqual(PickerGeometry.columnCount(for: 120), 4)
        XCTAssertGreaterThan(PickerGeometry.columnCount(for: 520), 4)
    }

    func testMenuBarRecentGridCentersCellsInExpandedMenu() {
        XCTAssertEqual(MenuBarRecentGrid.horizontalInset(for: 245), 17.5, accuracy: 0.001)
        XCTAssertEqual(MenuBarRecentGrid.horizontalInset(for: 279), 34.5, accuracy: 0.001)
    }

    func testSearchTextCanBeDrivenWithoutTextFieldFocus() {
        let model = PickerViewModel(
            bundleID: "tests",
            compact: false,
            onSelect: { _, _ in },
            onDismiss: {}
        )

        model.appendSearchText("ele")
        XCTAssertEqual(model.query, "ele")

        model.deleteBackwardInSearch()
        XCTAssertEqual(model.query, "el")
    }

    func testClickSelectionUsesEntryCharacter() {
        let expectation = expectation(description: "selection completes after feedback")
        var selected: String?
        var keptOpen: Bool?
        let model = PickerViewModel(
            bundleID: "tests",
            compact: false,
            onSelect: {
                selected = $0
                keptOpen = $1
                expectation.fulfill()
            },
            onDismiss: {}
        )
        let entry = PickerEntry(
            id: "entry",
            character: "✓",
            name: "Check",
            shortcode: "check",
            keywords: [],
            category: "tests"
        )

        model.select(entry, keepOpen: true)

        XCTAssertEqual(model.confirmingEntryID, entry.id)
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(selected, "✓")
        XCTAssertEqual(keptOpen, true)
        XCTAssertNil(model.confirmingEntryID)
    }

    func testCopyWritesEntryCharacterToPasteboard() {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        defer {
            pasteboard.clearContents()
            if let previous {
                pasteboard.setString(previous, forType: .string)
            }
        }

        let model = PickerViewModel(
            bundleID: "tests",
            compact: false,
            onSelect: { _, _ in },
            onDismiss: {}
        )
        let entry = PickerEntry(
            id: "entry",
            character: "→",
            name: "Right Arrow",
            shortcode: "arrow_right",
            keywords: [],
            category: "tests"
        )

        model.copy(entry)

        XCTAssertEqual(pasteboard.string(forType: .string), "→")
        XCTAssertEqual(model.copiedEntryID, entry.id)
    }

    func testCategoryFilterLimitsDefaultResults() {
        let model = PickerViewModel(
            bundleID: "tests",
            compact: false,
            onSelect: { _, _ in },
            onDismiss: {}
        )

        model.selectCategory(PickerCategory.defaults.first { $0.id == "math" }!)

        XCTAssertFalse(model.results.isEmpty)
        XCTAssertTrue(model.results.allSatisfy { $0.category == "math" })
    }

    func testEscapeClearsQueryBeforeDismissing() {
        var dismissed = false
        let model = PickerViewModel(
            bundleID: "tests",
            compact: false,
            onSelect: { _, _ in },
            onDismiss: { dismissed = true }
        )

        model.query = "arrow"
        model.handleEscape()

        XCTAssertEqual(model.query, "")
        XCTAssertFalse(dismissed)

        model.handleEscape()

        XCTAssertTrue(dismissed)
    }
}
