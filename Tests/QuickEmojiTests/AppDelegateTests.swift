import AppKit
import XCTest
@testable import QuickEmoji

@MainActor
final class AppDelegateTests: XCTestCase {
    func testSupportItemIsTheOptionAlternateForAbout() {
        let target = MenuTarget()
        let items = AppDelegate.makeAboutMenuItems(
            target: target,
            aboutAction: #selector(MenuTarget.about),
            supportAction: #selector(MenuTarget.support)
        )
        let menu = NSMenu()
        menu.addItem(items.about)
        menu.addItem(items.support)

        XCTAssertEqual(menu.items.count, 2)
        XCTAssertEqual(menu.items[0].title, L10n.string("About QuickEmoji"))
        XCTAssertFalse(menu.items[0].isAlternate)
        XCTAssertEqual(menu.items[1].title, L10n.string("Support QuickEmoji"))
        XCTAssertTrue(menu.items[1].isAlternate)
        XCTAssertEqual(menu.items[1].keyEquivalentModifierMask, [.option])
    }
}

private final class MenuTarget: NSObject {
    @objc func about() {}

    @objc func support() {}
}
