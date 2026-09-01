import XCTest
@testable import QuickEmoji

@MainActor
final class AppSettingsTests: XCTestCase {
    func testLaunchAtLoginToggleReflectsControllerState() {
        let controller = MockLoginItemController()
        let settings = AppSettings(loginItemController: controller)

        XCTAssertEqual(settings.launchAtLoginStatus, .disabled)

        settings.toggleLaunchAtLogin()

        XCTAssertEqual(settings.launchAtLoginStatus, .enabled)

        settings.toggleLaunchAtLogin()

        XCTAssertEqual(settings.launchAtLoginStatus, .disabled)
    }

    func testLaunchAtLoginApprovalOpensSystemSettings() {
        let controller = MockLoginItemController(status: .requiresApproval)
        let settings = AppSettings(loginItemController: controller)

        settings.toggleLaunchAtLogin()

        XCTAssertTrue(controller.didOpenSystemSettings)
        XCTAssertEqual(controller.setEnabledCalls, [])
    }
}

private final class MockLoginItemController: LoginItemControlling {
    var status: LoginItemStatus
    var didOpenSystemSettings = false
    var setEnabledCalls: [Bool] = []

    init(status: LoginItemStatus = .disabled) {
        self.status = status
    }

    func setEnabled(_ enabled: Bool) throws {
        setEnabledCalls.append(enabled)
        status = enabled ? .enabled : .disabled
    }

    func openSystemSettings() {
        didOpenSystemSettings = true
    }
}
