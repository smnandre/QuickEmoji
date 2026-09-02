import XCTest
@testable import QuickEmoji

final class AppResourcesTests: XCTestCase {
    func testResourceBundleContainsRequiredFiles() {
        XCTAssertNotNil(
            AppResources.bundle.url(forResource: "Localizable", withExtension: "xcstrings")
        )
        XCTAssertNotNil(
            AppResources.bundle.url(forResource: "EmojiNames.fr", withExtension: "json")
        )
        XCTAssertNotNil(
            AppResources.bundle.url(forResource: "Icon", withExtension: "icns")
        )
        XCTAssertNotNil(
            AppResources.bundle.url(forResource: "UnicodeLicense", withExtension: "txt")
        )
    }

    func testSupportURLUsesPersonalWebsite() {
        XCTAssertEqual(AppInfo.supportURL.absoluteString, "https://smnandre.dev")
    }
}
