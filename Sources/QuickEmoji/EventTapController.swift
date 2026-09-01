import AppKit
import Carbon.HIToolbox

@MainActor
final class EventTapController {
    private let onHotKey: @MainActor () -> Void
    private let onKeyEvent: @MainActor (CGEvent) -> Bool
    private var accessibilityGate = AccessibilityPermissionGate()
    private var didRequestAccessibilityPrompt = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pollTimer: Timer?

    init(
        onHotKey: @escaping @MainActor () -> Void,
        onKeyEvent: @escaping @MainActor (CGEvent) -> Bool
    ) {
        self.onHotKey = onHotKey
        self.onKeyEvent = onKeyEvent
    }

    func start() {
        if registerEventTap() {
            return
        }

        accessibilityGate.resetIfPermissionMissing(isTrusted: false)
        requestAccessibilityPromptIfNeeded()
        startAccessibilityPolling()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func requestAccessibilityPromptIfNeeded() {
        guard !didRequestAccessibilityPrompt else { return }
        didRequestAccessibilityPrompt = true

        let key = "AXTrustedCheckOptionPrompt" as CFString
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private func startAccessibilityPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard self != nil else {
                timer.invalidate()
                return
            }
            Task { @MainActor [weak self] in
                self?.checkAccessibilityPermission()
            }
        }
    }

    private func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        accessibilityGate.resetIfPermissionMissing(isTrusted: trusted)
        guard accessibilityGate.shouldRegisterEventTap(isTrusted: trusted) else { return }

        guard registerEventTap() else {
            accessibilityGate.resetAfterRegistrationFailure()
            return
        }

        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func registerEventTap() -> Bool {
        guard eventTap == nil else { return true }
        guard AXIsProcessTrusted() else { return false }

        let eventMask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: eventMask,
                callback: { _, type, event, userInfo in
                    guard let userInfo else { return Unmanaged.passUnretained(event) }
                    let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
                    return controller.handle(type: type, event: event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            AppLogger.eventTap.error("Creating the global event tap failed")
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            AppLogger.eventTap.notice("Re-enabled the global event tap")
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        if Self.isHotKey(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { [weak self] in
                self?.onHotKey()
            }
            return nil
        }

        return onKeyEvent(event) ? nil : Unmanaged.passUnretained(event)
    }

    nonisolated static func isHotKey(keyCode: Int, flags: CGEventFlags) -> Bool {
        let forbiddenFlags: CGEventFlags = [.maskControl, .maskAlternate]
        return keyCode == kVK_ANSI_E
            && flags.contains([.maskCommand, .maskShift])
            && flags.intersection(forbiddenFlags).isEmpty
    }
}
