import AppKit
import SwiftUI

@MainActor
final class PickerWindow: NSPanel, NSWindowDelegate {
    private static let autosaveName = "QuickEmojiPickerWindow"
    private static var warmedPickerView: NSHostingView<PickerContentView>?

    private let onDismiss: () -> Void
    private let viewModel: PickerViewModel
    private var keyMonitor: Any?
    private var outsideClickMonitor: Any?
    private var isClosingFromAction = false
    private var isKeepingOpenForInsertion = false

    init(
        caret: CaretResult,
        bundleID: String,
        onSelect: @escaping (String, Bool) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onDismiss = onDismiss

        let screen = Self.activeScreen() ?? caret.screen
        let visibleFrame = screen.visibleFrame
        let frame = PanelGeometry.pickerDefaultFrame(size: PickerGeometry.defaultSize, in: visibleFrame)

        self.viewModel = PickerViewModel(
            bundleID: bundleID,
            onSelect: onSelect,
            onDismiss: onDismiss
        )

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        delegate = self
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        sharingType = .none
        minSize = PickerGeometry.minimumSize
        maxSize = PickerGeometry.maximumSize

        let hosting = NSHostingView(rootView: PickerContentView(viewModel: viewModel))
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        contentView = hosting

        restoreSavedFrameIfUsable(defaultFrame: frame)
        setFrameAutosaveName(Self.autosaveName)
    }

    func show() {
        installKeyMonitor()
        installOutsideClickMonitor()
        NSApp.activate()
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        makeMain()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let hosting = self.contentView else { return }
            self.makeKey()
            self.makeMain()
            self.makeFirstResponder(hosting)
            self.viewModel.requestSearchFocus()
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        requestDismiss()
    }

    override func close() {
        saveFrame(usingName: Self.autosaveName)
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        super.close()
    }

    override func keyDown(with event: NSEvent) {
        if handleKeyEvent(event) { return }
        super.keyDown(with: event)
    }

    func handleGlobalKeyEvent(_ event: CGEvent) -> Bool {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        switch keyCode {
        case 123:
            viewModel.moveLeft()
            return true
        case 124:
            viewModel.moveRight()
            return true
        case 126:
            viewModel.moveUp()
            return true
        case 125:
            viewModel.moveDown()
            return true
        case 36:
            let keepOpen = flags.contains(.maskShift)
            isClosingFromAction = !keepOpen
            viewModel.selectCurrent(keepOpen: keepOpen)
            return true
        case 48:
            requestDismiss()
            return true
        case 53:
            handleEscape()
            return true
        case 51, 117:
            if viewModel.isAllSearchTextSelected {
                viewModel.deleteBackwardInSearch()
                return true
            }
            if Self.usesNativeTextEditing(
                isApplicationActive: NSApp.isActive,
                isPickerKeyWindow: isKeyWindow
            ) {
                return false
            }
            if keyCode == 51 {
                viewModel.deleteBackwardInSearch()
            }
            return true
        default:
            break
        }

        if Self.isSelectAllShortcut(
            charactersIgnoringModifiers: NSEvent(cgEvent: event)?.charactersIgnoringModifiers,
            flags: flags
        ) {
            selectAllSearchText()
            return true
        }

        if Self.usesNativeTextEditing(
            isApplicationActive: NSApp.isActive,
            isPickerKeyWindow: isKeyWindow
        ) {
            return false
        }

        let hasCommandControlOrOption =
            flags.contains(.maskCommand)
            || flags.contains(.maskControl)
            || flags.contains(.maskAlternate)
        guard !hasCommandControlOrOption else { return false }

        var length = 0
        var chars = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(
            maxStringLength: chars.count,
            actualStringLength: &length,
            unicodeString: &chars
        )

        if length > 0 {
            let text = String(utf16CodeUnits: &chars, count: length)
            if text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
                viewModel.appendSearchText(text)
                return true
            }
        }
        requestDismiss()
        return true
    }

    func windowDidResignKey(_ notification: Notification) {
        guard isVisible, !isClosingFromAction, !isKeepingOpenForInsertion else { return }
        requestDismiss()
    }

    @MainActor
    static func prewarm(bundleID: String) {
        guard warmedPickerView == nil else { return }
        let model = PickerViewModel(
            bundleID: bundleID,
            onSelect: { _, _ in },
            onDismiss: {}
        )
        let view = PickerContentView(viewModel: model)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: PickerGeometry.defaultSize)
        warmedPickerView = hosting
        _ = EmojiSearch.shared.defaultEntries(bundleID: bundleID)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible, event.window === self else { return event }
            return self.handleKeyEvent(event) ? nil : event
        }
    }

    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            guard let self, self.isVisible,
                !self.isClosingFromAction, !self.isKeepingOpenForInsertion
            else { return }
            self.requestDismiss()
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        switch Int(event.keyCode) {
        case 123:
            viewModel.moveLeft()
            return true
        case 124:
            viewModel.moveRight()
            return true
        case 126:
            viewModel.moveUp()
            return true
        case 125:
            viewModel.moveDown()
            return true
        case 36:
            let keepOpen = event.modifierFlags.contains(.shift)
            isClosingFromAction = !keepOpen
            viewModel.selectCurrent(keepOpen: keepOpen)
            return true
        case 48:
            requestDismiss()
            return true
        case 53:
            handleEscape()
            return true
        default:
            return false
        }
    }

    func prepareForKeptOpenInsertion() {
        isKeepingOpenForInsertion = true
    }

    func restoreAfterKeptOpenInsertion() {
        isKeepingOpenForInsertion = false
        NSApp.activate()
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        makeMain()
        viewModel.requestSearchFocus()
    }

    private func requestDismiss() {
        isClosingFromAction = true
        onDismiss()
    }

    private func handleEscape() {
        requestDismiss()
    }

    private func selectAllSearchText() {
        NSApp.activate()
        makeKeyAndOrderFront(nil)
        makeKey()
        viewModel.requestSelectAll()
    }

    nonisolated static func usesNativeTextEditing(
        isApplicationActive: Bool,
        isPickerKeyWindow: Bool
    ) -> Bool {
        isApplicationActive && isPickerKeyWindow
    }

    nonisolated static func isSelectAllShortcut(
        charactersIgnoringModifiers: String?,
        flags: CGEventFlags
    ) -> Bool {
        charactersIgnoringModifiers?.lowercased() == "a"
            && flags.contains(.maskCommand)
            && flags.intersection([.maskShift, .maskAlternate, .maskControl]).isEmpty
    }

    private func restoreSavedFrameIfUsable(defaultFrame: CGRect) {
        guard setFrameUsingName(Self.autosaveName) else { return }
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        if !PanelGeometry.isUsableSavedFrame(frame, visibleFrames: visibleFrames) {
            setFrame(defaultFrame, display: false)
        } else if frame.size != defaultFrame.size {
            setFrame(framePreservingTopCenter(size: defaultFrame.size), display: false)
        }
    }

    private func framePreservingTopCenter(size: CGSize) -> CGRect {
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
        return CGRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        .clamped(to: visibleFrame, gap: PanelGeometry.edgeGap)
    }

    private static func activeScreen() -> NSScreen? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard result == .success, let window = windowRef else { return nil }

        var posRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window as! AXUIElement, kAXPositionAttribute as CFString, &posRef)
        guard let posVal = posRef else { return nil }

        var pos = CGPoint.zero
        AXValueGetValue(posVal as! AXValue, .cgPoint, &pos)

        guard let primary = NSScreen.screens.first else { return nil }
        let nsPoint = NSPoint(x: pos.x + 100, y: primary.frame.height - pos.y - 100)
        return NSScreen.screens.first { NSPointInRect(nsPoint, $0.frame) }
    }
}
