import AppKit

struct CaretResult {
    enum Source {
        case accessibilityCaret
        case focusedWindowFallback
        case mouseFallback
    }

    let point: NSPoint
    let lineHeight: CGFloat
    let screen: NSScreen
    let source: Source
    let isEditable: Bool
}

struct FocusedTextContext {
    let element: AXUIElement
    let value: String
    let selectedRange: CFRange
}

@MainActor
enum CaretLocator {
    private struct CachedCaretResult {
        let pid: pid_t
        let timestamp: TimeInterval
        let result: CaretResult
    }

    private static let cacheLifetime: TimeInterval = 0.12
    private static var cachedResult: CachedCaretResult?

    static func locate(forceRefresh: Bool = false) -> CaretResult {
        if !forceRefresh,
            let app = NSWorkspace.shared.frontmostApplication,
            let cachedResult,
            cachedResult.pid == app.processIdentifier,
            Date.timeIntervalSinceReferenceDate - cachedResult.timestamp <= cacheLifetime
        {
            return cachedResult.result
        }

        let result: CaretResult
        if let accessibilityResult = accessibilityCaretResult() {
            result = accessibilityResult
        } else if let fallbackResult = focusedWindowFallback() {
            result = fallbackResult
        } else {
            let mouse = NSEvent.mouseLocation
            let screen = screenContaining(mouse) ?? NSScreen.main ?? NSScreen.screens[0]
            result = CaretResult(
                point: mouse, lineHeight: 16, screen: screen, source: .mouseFallback, isEditable: false)
        }

        if let app = NSWorkspace.shared.frontmostApplication {
            cachedResult = CachedCaretResult(
                pid: app.processIdentifier,
                timestamp: Date.timeIntervalSinceReferenceDate,
                result: result
            )
        }

        return result
    }

    static func invalidateCache() {
        cachedResult = nil
    }

    static func focusedTextContext() -> FocusedTextContext? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        return focusedTextContext(for: pid)
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

        let lineHeight = max(rect.size.height, 14)

        let baselineY = screenHeight - (rect.origin.y + rect.size.height)
        let point = NSPoint(x: rect.origin.x, y: baselineY)

        let screen = screenContaining(point) ?? primaryScreen
        return CaretResult(
            point: point,
            lineHeight: lineHeight,
            screen: screen,
            source: .accessibilityCaret,
            isEditable: focusedElementContext.isEditable
        )
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
        return CaretResult(
            point: point, lineHeight: 16, screen: screen, source: .focusedWindowFallback, isEditable: false)
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
