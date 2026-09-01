import XCTest
@testable import QuickEmoji

final class AppContextTests: XCTestCase {
    func testTerminalBundleIdentifiersAreDetectedWithoutFrontmostApplicationState() {
        XCTAssertTrue(AppContext.isTerminal(bundleID: "com.apple.Terminal"))
        XCTAssertTrue(AppContext.isTerminal(bundleID: "com.mitchellh.ghostty"))
        XCTAssertFalse(AppContext.isTerminal(bundleID: "com.apple.TextEdit"))
        XCTAssertFalse(AppContext.isTerminal(bundleID: ""))
    }
}
