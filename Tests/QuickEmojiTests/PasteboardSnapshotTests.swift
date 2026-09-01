import AppKit
import XCTest
@testable import QuickEmoji

final class PasteboardSnapshotTests: XCTestCase {
    func testSnapshotRestoresMultiplePasteboardItemsAndTypes() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        let first = NSPasteboardItem()
        first.setString("plain text", forType: .string)
        first.setData(Data([0x01, 0x02, 0x03]), forType: .init("dev.smnandre.quickemoji.test-data"))
        let second = NSPasteboardItem()
        second.setString("second item", forType: .string)
        pasteboard.clearContents()
        pasteboard.writeObjects([first, second])

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("temporary", forType: .string)

        let temporaryChangeCount = pasteboard.changeCount
        XCTAssertTrue(snapshot.restore(to: pasteboard, ifUnchangedSince: temporaryChangeCount))

        let items = pasteboard.pasteboardItems ?? []
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].string(forType: .string), "plain text")
        XCTAssertEqual(items[0].data(forType: .init("dev.smnandre.quickemoji.test-data")), Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(items[1].string(forType: .string), "second item")
    }

    func testSnapshotDoesNotOverwriteAChangedPasteboard() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("temporary", forType: .string)
        let temporaryChangeCount = pasteboard.changeCount
        pasteboard.clearContents()
        pasteboard.setString("new user value", forType: .string)

        XCTAssertFalse(snapshot.restore(to: pasteboard, ifUnchangedSince: temporaryChangeCount))
        XCTAssertEqual(pasteboard.string(forType: .string), "new user value")
    }
}
