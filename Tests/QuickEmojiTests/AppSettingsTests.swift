import XCTest
@testable import QuickEmoji

@MainActor
final class AppSettingsTests: XCTestCase {
    func testLaunchAtLoginSettingReflectsControllerState() {
        let controller = MockLoginItemController()
        let settings = AppSettings(loginItemController: controller)

        XCTAssertEqual(settings.launchAtLoginStatus, .disabled)

        settings.setLaunchAtLogin(true)

        XCTAssertEqual(settings.launchAtLoginStatus, .enabled)

        settings.setLaunchAtLogin(false)

        XCTAssertEqual(settings.launchAtLoginStatus, .disabled)
        XCTAssertEqual(controller.setEnabledCalls, [true, false])
    }

    func testLaunchAtLoginApprovalOpensSystemSettings() {
        let controller = MockLoginItemController(status: .requiresApproval)
        let settings = AppSettings(loginItemController: controller)

        settings.setLaunchAtLogin(true)

        XCTAssertTrue(controller.didOpenSystemSettings)
        XCTAssertEqual(controller.setEnabledCalls, [])
    }

    func testLaunchAtLoginSettingDoesNotRepeatCurrentState() {
        let controller = MockLoginItemController(status: .enabled)
        let settings = AppSettings(loginItemController: controller)

        settings.setLaunchAtLogin(true)

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
