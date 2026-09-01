import Foundation

struct AccessibilityPermissionGate {
    private(set) var didRegisterAfterGrant = false

    mutating func shouldRegisterEventTap(isTrusted: Bool) -> Bool {
        guard isTrusted, !didRegisterAfterGrant else { return false }
        didRegisterAfterGrant = true
        return true
    }

    mutating func resetIfPermissionMissing(isTrusted: Bool) {
        if !isTrusted {
            didRegisterAfterGrant = false
        }
    }

    mutating func resetAfterRegistrationFailure() {
        didRegisterAfterGrant = false
    }
}
