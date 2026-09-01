import AppKit

struct CaretResult {
    let screen: NSScreen
}

struct FocusedTextContext {
    let element: AXUIElement
    let value: String
    let selectedRange: CFRange
}

@MainActor
enum CaretLocator {
    static func locate() -> CaretResult {
        if let accessibilityResult = accessibilityCaretResult() {
            return accessibilityResult
        }
        if let fallbackResult = focusedWindowFallback() {
            return fallbackResult
        }
        let screen = screenContaining(NSEvent.mouseLocation) ?? NSScreen.main ?? NSScreen.screens[0]
        return CaretResult(screen: screen)
    }

    static func focusedTextContext(for pid: pid_t) -> FocusedTextContext? {
        guard let context = focusedElementContext(for: pid),
            context.isEditable,
            let selectedRange = selectedRange(for: context.element)
        else { return nil }

        var valueRef: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(
            context.element,
            kAXValueAttribute as CFString,
            &valueRef
        )
        guard valueResult == .success, let value = valueRef as? String else { return nil }

        return FocusedTextContext(
            element: context.element,
            value: value,
            selectedRange: selectedRange
        )
    }

    private static func accessibilityCaretResult() -> CaretResult? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
            let focusedElementContext = focusedElementContext(for: pid),
            let range = selectedRangeValue(for: focusedElementContext.element)
        else {
            return nil
        }

        var bounds: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            focusedElementContext.element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            range,
            &bounds
        )

        guard boundsResult == .success,
            let boundsValue = bounds,
            CFGetTypeID(boundsValue) == AXValueGetTypeID()
        else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) else { return nil }

        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let screenHeight = primaryScreen.frame.height

        let baselineY = screenHeight - (rect.origin.y + rect.size.height)
        let point = NSPoint(x: rect.origin.x, y: baselineY)

        let screen = screenContaining(point) ?? primaryScreen
        return CaretResult(screen: screen)
    }

    private static func focusedWindowFallback() -> CaretResult? {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else { return nil }

        let appElement = AXUIElementCreateApplication(focusedApp.processIdentifier)

        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard result == .success,
            let window = windowRef,
            CFGetTypeID(window) == AXUIElementGetTypeID()
        else { return nil }

        let axWindow = window as! AXUIElement

        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionRef)
        AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeRef)

        guard let posVal = positionRef,
            let sizeVal = sizeRef,
            CFGetTypeID(posVal) == AXValueGetTypeID(),
            CFGetTypeID(sizeVal) == AXValueGetTypeID()
        else { return nil }

        var pos = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &pos),
            AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        else { return nil }

        guard let primaryScreen = NSScreen.screens.first else { return nil }
        let screenHeight = primaryScreen.frame.height

        let axY = pos.y + 80
        let point = NSPoint(
            x: pos.x + size.width / 2,
            y: screenHeight - axY
        )

        let screen = screenContaining(point) ?? primaryScreen
        return CaretResult(screen: screen)
    }

    private static func checkEditable(_ element: AXUIElement) -> Bool {
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String ?? ""

        let editableRoles: Set<String> = ["AXTextArea", "AXTextField", "AXComboBox", "AXSearchField"]
        return editableRoles.contains(role)
    }

    private static func screenContaining(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSPointInRect(point, $0.frame) }
    }

    private static func focusedElementContext(for pid: pid_t) -> (element: AXUIElement, isEditable: Bool)? {
        let appElement = AXUIElementCreateApplication(pid)

        var focusedElement: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard focusResult == .success,
            let element = focusedElement,
            CFGetTypeID(element) == AXUIElementGetTypeID()
        else { return nil }

        let axElement = element as! AXUIElement
        return (axElement, checkEditable(axElement))
    }

    private static func selectedRange(for element: AXUIElement) -> CFRange? {
        guard let selectedRangeValue = selectedRangeValue(for: element) else { return nil }
        var range = CFRange()
        guard AXValueGetValue(selectedRangeValue, .cfRange, &range) else { return nil }
        return range
    }

    private static func selectedRangeValue(for element: AXUIElement) -> AXValue? {
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        guard rangeResult == .success,
            let range = selectedRange,
            CFGetTypeID(range) == AXValueGetTypeID()
        else { return nil }
        return (range as! AXValue)
    }
}
