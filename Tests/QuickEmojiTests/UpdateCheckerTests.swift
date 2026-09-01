import XCTest
@testable import QuickEmoji

final class UpdateCheckerTests: XCTestCase {
    func testAppVersionAcceptsStableSemanticVersions() {
        XCTAssertEqual(AppVersion("1.0.0")?.rawValue, "1.0.0")
        XCTAssertEqual(AppVersion("v1.2.3")?.rawValue, "1.2.3")
    }

    func testAppVersionRejectsMalformedVersions() {
        for value in ["dev", "1.2", "1.2.3.4", "1.two.3", "+1.0.0", "1.0.0-beta.1"] {
            XCTAssertNil(AppVersion(value))
        }
    }

    func testAppVersionComparesNumericComponents() throws {
        let older = try XCTUnwrap(AppVersion("0.9.9"))
        let newer = try XCTUnwrap(AppVersion("1.0.0"))

        XCTAssertLessThan(older, newer)
    }

    func testParsesPublishedVersionFromHomebrewCask() throws {
        let release = try UpdateChecker.parsePublishedRelease(
            from: """
                cask "quickemoji" do
                  version "1.0.0"
                  sha256 "abc"
                end
                """)

        XCTAssertEqual(release.version, AppVersion("1.0.0"))
        XCTAssertEqual(
            release.releaseURL.absoluteString,
            "https://github.com/smnandre/QuickEmoji/releases/tag/v1.0.0"
        )
    }

    func testReportsAvailableUpdate() async throws {
        let release = try makeRelease(version: "1.0.1")
        let checker = UpdateChecker(fetchPublishedRelease: { release })

        let result = try await checker.check(currentVersion: "1.0.0")

        XCTAssertEqual(result, .updateAvailable(release))
    }

    func testTreatsCurrentAndOlderCasksAsUpToDate() async throws {
        for version in ["1.0.0", "0.10.3"] {
            let release = try makeRelease(version: version)
            let checker = UpdateChecker(fetchPublishedRelease: { release })

            let result = try await checker.check(currentVersion: "1.0.0")

            XCTAssertEqual(result, .upToDate(release))
        }
    }

    func testRejectsCaskWithoutStableVersion() {
        XCTAssertThrowsError(
            try UpdateChecker.parsePublishedRelease(from: "version \"1.0.0-beta.1\"")
        )
    }

    func testUsesPublishedHomebrewTap() {
        XCTAssertEqual(AppInfo.websiteURL.absoluteString, "https://smnand.re/quickemoji")
        XCTAssertEqual(
            AppInfo.publishedCaskURL.absoluteString,
            "https://raw.githubusercontent.com/smnandre/homebrew-tap/main/Casks/quickemoji.rb"
        )
        XCTAssertEqual(AppInfo.homebrewUpgradeCommand, "brew upgrade --cask quickemoji")
    }

    private func makeRelease(version: String) throws -> PublishedCaskRelease {
        let appVersion = try XCTUnwrap(AppVersion(version))
        let url = try XCTUnwrap(URL(string: "https://github.com/smnandre/QuickEmoji/releases/tag/v\(version)"))
        return PublishedCaskRelease(version: appVersion, releaseURL: url)
    }
}
