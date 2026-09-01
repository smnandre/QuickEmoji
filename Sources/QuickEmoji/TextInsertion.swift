import AppKit

@MainActor
final class TextInsertionCoordinator {
    private static let activationPollInterval: TimeInterval = 0.01
    private static let activationTimeout: TimeInterval = 0.5

    func activateAndInsert(
        _ character: String,
        into app: NSRunningApplication,
        completion: @escaping @MainActor (_ usedDirectReplacement: Bool) -> Void
    ) {
        let isTerminal = AppContext.isTerminal(bundleID: app.bundleIdentifier ?? "")
        AppLogger.insertion.debug(
            "Activating \(app.localizedName ?? "unknown", privacy: .public), pid \(app.processIdentifier)"
        )
        let didActivate = app.activate()
        AppLogger.insertion.debug("Activation returned \(didActivate)")
        let startTime = CFAbsoluteTimeGetCurrent()
        pollForAXAndInsert(
            character,
            targetApp: app,
            isTerminal: isTerminal,
            startTime: startTime,
            deadline: .now() + Self.activationTimeout,
            completion: completion
        )
    }

    private func pasteViaClipboard(_ character: String) {
        let pasteboard = NSPasteboard.general
        let previous = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(character, forType: .string)
        let temporaryChangeCount = pasteboard.changeCount

        let source = CGEventSource(stateID: .combinedSessionState)

        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        up?.flags = .maskCommand

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            previous.restore(to: pasteboard, ifUnchangedSince: temporaryChangeCount)
        }
    }

    private func replaceText(in overrideRange: NSRange?, with character: String, context: FocusedTextContext) -> Bool {
        let value = context.value as NSString
        let replacementRange =
            overrideRange
            ?? NSRange(
                location: context.selectedRange.location,
                length: context.selectedRange.length
            )
        guard replacementRange.location >= 0,
            replacementRange.length >= 0,
            replacementRange.location + replacementRange.length <= value.length
        else {
            AppLogger.insertion.error(
                "Replacement range \(String(describing: replacementRange), privacy: .public) exceeds value length \(value.length)"
            )
            return false
        }

        let updatedValue = value.replacingCharacters(in: replacementRange, with: character)
        var finalRange = CFRange(
            location: replacementRange.location + (character as NSString).length,
            length: 0
        )
        let setValueResult = AXUIElementSetAttributeValue(
            context.element,
            kAXValueAttribute as CFString,
            updatedValue as CFTypeRef
        )
        if setValueResult != .success {
            AppLogger.insertion.error("Setting the AX value failed with code \(setValueResult.rawValue)")
            return false
        }

        guard let selectionValue = AXValueCreate(.cfRange, &finalRange) else {
            AppLogger.insertion.error("Creating the AX selection range failed")
            return true
        }

        let setSelectedResult = AXUIElementSetAttributeValue(
            context.element,
            kAXSelectedTextRangeAttribute as CFString,
            selectionValue
        )
        if setSelectedResult != .success {
            AppLogger.insertion.error("Setting the AX selection failed with code \(setSelectedResult.rawValue)")
        }
        return true
    }

    private func pollForAXAndInsert(
        _ character: String,
        targetApp app: NSRunningApplication,
        isTerminal: Bool,
        startTime: CFTimeInterval,
        deadline: DispatchTime,
        completion: @escaping @MainActor (_ usedDirectReplacement: Bool) -> Void
    ) {
        let pid = app.processIdentifier
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        if !isTerminal {
            if let context = CaretLocator.focusedTextContext(for: pid) {
                let success = replaceText(in: nil, with: character, context: context)
                AppLogger.insertion.debug(
                    "AX replacement completed after \(elapsed, format: .fixed(precision: 2)) ms: \(success)"
                )
                completion(success)
                return
            }
        }

        let settledDelay: CFTimeInterval = isTerminal ? 150 : 200

        if app.isActive && elapsed >= settledDelay {
            AppLogger.insertion.debug(
                "Using pasteboard fallback after \(elapsed, format: .fixed(precision: 2)) ms"
            )
            pasteViaClipboard(character)
            completion(false)
            return
        }

        if DispatchTime.now() >= deadline {
            AppLogger.insertion.debug(
                "Using pasteboard fallback after timeout at \(elapsed, format: .fixed(precision: 2)) ms"
            )
            pasteViaClipboard(character)
            completion(false)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.activationPollInterval) { [weak self] in
            self?.pollForAXAndInsert(
                character,
                targetApp: app,
                isTerminal: isTerminal,
                startTime: startTime,
                deadline: deadline,
                completion: completion
            )
        }
    }
}

struct PasteboardSnapshot {
    private let items: [NSPasteboardItem]

    private init(items: [NSPasteboardItem]) {
        self.items = items
    }

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let copiedItems = pasteboard.pasteboardItems?.map(Self.copyItem) ?? []
        return PasteboardSnapshot(items: copiedItems)
    }

    @discardableResult
    func restore(to pasteboard: NSPasteboard, ifUnchangedSince changeCount: Int? = nil) -> Bool {
        if let changeCount, pasteboard.changeCount != changeCount {
            return false
        }
        pasteboard.clearContents()
        guard !items.isEmpty else { return true }
        pasteboard.writeObjects(items)
        return true
    }

    private static func copyItem(_ item: NSPasteboardItem) -> NSPasteboardItem {
        let copy = NSPasteboardItem()
        for type in item.types {
            if let data = item.data(forType: type) {
                copy.setData(data, forType: type)
            }
        }
        return copy
    }
}
