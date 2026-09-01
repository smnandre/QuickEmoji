import Foundation
import Observation
import ServiceManagement

enum LoginItemStatus: Equatable {
    case disabled
    case enabled
    case requiresApproval
}

protocol LoginItemControlling {
    var status: LoginItemStatus { get }
    func setEnabled(_ enabled: Bool) throws
    func openSystemSettings()
}

struct SMLoginItemController: LoginItemControlling {
    private let service = SMAppService.mainApp

    var status: LoginItemStatus {
        switch service.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        default:
            return .disabled
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let loginItemController: LoginItemControlling

    init(loginItemController: LoginItemControlling = SMLoginItemController()) {
        self.loginItemController = loginItemController
    }

    var launchAtLoginStatus: LoginItemStatus {
        access(keyPath: \.launchAtLoginStatus)
        return loginItemController.status
    }

    func toggleLaunchAtLogin() {
        withMutation(keyPath: \.launchAtLoginStatus) {
            do {
                switch loginItemController.status {
                case .disabled:
                    try loginItemController.setEnabled(true)
                case .enabled:
                    try loginItemController.setEnabled(false)
                case .requiresApproval:
                    loginItemController.openSystemSettings()
                }
            } catch {
                AppLogger.settings.error(
                    "Failed to update launch at login: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
