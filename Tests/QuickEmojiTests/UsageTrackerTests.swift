import XCTest
@testable import QuickEmoji

@MainActor
final class UsageTrackerTests: XCTestCase {
    func testFlushPendingSavesPersistsImmediately() {
        let suiteName = #function + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let tracker = UsageTracker(defaults: defaults, storageKey: "usage")
        tracker.recordUsage("✓", bundleID: "com.example")
        tracker.flushPendingSaves()

        let reloaded = UsageTracker(defaults: defaults, storageKey: "usage")

        XCTAssertEqual(reloaded.rankedCharacters(for: "com.example", limit: 1), ["✓"])
    }

    func testRecentCharactersOrderedByMostRecentUse() {
        let tracker = makeTracker()

        tracker.recordUsage("a", bundleID: "app")
        tracker.recordUsage("b", bundleID: "app")
        tracker.recordUsage("c", bundleID: "app")

        XCTAssertEqual(tracker.recentCharacters(limit: 3), ["c", "b", "a"])
    }

    func testRankedCharactersAreScopedToTheRequestedApp() {
        let tracker = makeTracker()

        tracker.recordUsage("a", bundleID: "first")
        tracker.recordUsage("b", bundleID: "second")

        XCTAssertEqual(tracker.rankedCharacters(for: "first", limit: 10), ["a"])
        XCTAssertEqual(tracker.rankedCharacters(for: "second", limit: 10), ["b"])
    }

    func testRemoveDeletesCharacterAcrossApps() {
        let tracker = makeTracker()

        tracker.recordUsage("★", bundleID: "app1")
        tracker.recordUsage("★", bundleID: "app2")
        tracker.recordUsage("☆", bundleID: "app1")

        tracker.remove(character: "★")

        XCTAssertFalse(tracker.contains(character: "★"))
        XCTAssertTrue(tracker.contains(character: "☆"))
        XCTAssertEqual(tracker.recentCharacters(limit: 10), ["☆"])
    }

    func testClearEmptiesHistory() {
        let tracker = makeTracker()

        tracker.recordUsage("a", bundleID: "app")
        tracker.recordUsage("b", bundleID: "app")

        tracker.clear()

        XCTAssertTrue(tracker.recentCharacters(limit: 10).isEmpty)
        XCTAssertTrue(tracker.rankedCharacters(limit: 10).isEmpty)
        XCTAssertFalse(tracker.contains(character: "a"))
    }

    func testContainsReflectsRecordedCharacters() {
        let tracker = makeTracker()

        XCTAssertFalse(tracker.contains(character: "z"))
        tracker.recordUsage("z", bundleID: "app")
        XCTAssertTrue(tracker.contains(character: "z"))
    }

    private func makeTracker(function: String = #function) -> UsageTracker {
        let suiteName = function + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return UsageTracker(defaults: defaults, storageKey: "usage")
    }
}
