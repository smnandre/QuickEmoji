import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    private var statusItem: NSStatusItem!
    private var pickerWindow: PickerWindow?
    private var previousApp: NSRunningApplication?
    private var sourceBundleID = ""
    private let textInsertion = TextInsertionCoordinator()
    private let settings = AppSettings.shared
    private let updateChecker = UpdateChecker.live(caskURL: AppInfo.publishedCaskURL)
    private var updateTask: Task<Void, Never>?
    private weak var launchAtLoginMenuItem: NSMenuItem?
    private weak var recentGridItem: NSMenuItem?
    private lazy var eventTapController = EventTapController(
        onHotKey: { [weak self] in self?.showFullPicker() },
        onKeyEvent: { [weak self] event in
            guard let pickerWindow = self?.pickerWindow, pickerWindow.isVisible else { return false }
            return pickerWindow.handleGlobalKeyEvent(event)
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = AppContext.shared
        _ = EmojiSearch.shared
        PickerWindow.prewarm(bundleID: AppContext.shared.frontmostBundleID)
        setupMenuBar()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        eventTapController.start()
    }

    @objc private func openAccessibilitySettings() {
        eventTapController.openAccessibilitySettings()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = MenuBarIcon.make()
            button.toolTip = "QuickEmoji"
        }

        let menu = NSMenu()
        menu.delegate = self
        let showPickerItem = NSMenuItem(
            title: L10n.string("Show Picker"),
            action: #selector(showFullPicker),
            keyEquivalent: "e"
        )
        showPickerItem.target = self
        showPickerItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(showPickerItem)
        menu.addItem(.separator())

        let gridItem = NSMenuItem()
        gridItem.view = makeRecentGridView()
        menu.addItem(gridItem)
        self.recentGridItem = gridItem

        let clearRecentsItem = NSMenuItem(
            title: L10n.string("Clear Recents"),
            action: #selector(clearRecents),
            keyEquivalent: ""
        )
        clearRecentsItem.target = self
        menu.addItem(clearRecentsItem)
        menu.addItem(.separator())

        let checkUpdatesItem = NSMenuItem(
            title: L10n.string("Check for Updates…"),
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        checkUpdatesItem.target = self
        menu.addItem(checkUpdatesItem)

        let launchAtLoginItem = makeAlternateMenuItem(
            title: L10n.string("Launch at Login"),
            action: #selector(toggleLaunchAtLogin)
        )
        launchAtLoginItem.state = launchAtLoginMenuState
        menu.addItem(launchAtLoginItem)
        self.launchAtLoginMenuItem = launchAtLoginItem

        menu.addItem(.separator())
        let aboutItem = NSMenuItem(
            title: L10n.string("About QuickEmoji"),
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(
            makeAlternateMenuItem(
                title: L10n.string("Open Accessibility Settings"),
                action: #selector(openAccessibilitySettings)
            ))

        menu.addItem(
            NSMenuItem(
                title: L10n.string("Quit"),
                action: #selector(quit),
                keyEquivalent: "q"
            ))
        statusItem.menu = menu
    }

    private func makeAlternateMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isAlternate = true
        item.keyEquivalentModifierMask = [.option]
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        launchAtLoginMenuItem?.state = launchAtLoginMenuState
        recentGridItem?.view = makeRecentGridView()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(clearRecents) {
            return !UsageTracker.shared.recentCharacters(limit: 1).isEmpty
        }
        return true
    }

    private func makeRecentGridView() -> NSView {
        let entries = EmojiSearch.shared.menuBarRecentEntries(limit: MenuBarRecentGrid.capacity)
        return MenuBarRecentGrid.makeView(
            entries: entries,
            onCopy: { [weak self] entry in self?.copyFromMenuBar(entry) },
            onRemove: { entry in UsageTracker.shared.remove(character: entry.character) },
            closeMenu: { [weak self] in self?.statusItem.menu?.cancelTracking() }
        )
    }

    private func copyFromMenuBar(_ entry: PickerEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.character, forType: .string)
        EmojiSearch.shared.recordUsage(entry, bundleID: "")
    }

    @objc private func clearRecents() {
        UsageTracker.shared.clear()
    }

    @objc private func showFullPicker() {
        if let window = pickerWindow, window.isVisible {
            dismissPicker()
            previousApp?.activate()
            return
        }

        previousApp = AppContext.shared.frontmostApp
        sourceBundleID = AppContext.shared.frontmostBundleID
        let caret = CaretLocator.locate(forceRefresh: true)

        let window = PickerWindow(
            caret: caret,
            bundleID: sourceBundleID,
            onSelect: { @MainActor [weak self] character, keepOpen in
                guard let self else { return }
                guard let target = self.previousApp else {
                    if !keepOpen {
                        self.dismissPicker()
                    }
                    return
                }

                if !keepOpen {
                    self.dismissPicker()
                } else {
                    self.pickerWindow?.prepareForKeptOpenInsertion()
                }

                self.textInsertion.activateAndInsert(character, into: target) { direct in
                    guard keepOpen else { return }
                    if direct {
                        self.pickerWindow?.restoreAfterKeptOpenInsertion()
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.pickerWindow?.restoreAfterKeptOpenInsertion()
                        }
                    }
                }
            },
            onDismiss: { @MainActor [weak self] in
                self?.dismissPicker()
                self?.previousApp?.activate()
            }
        )

        pickerWindow = window
        window.show()
    }

    private func dismissPicker() {
        pickerWindow?.close()
        pickerWindow = nil
        CaretLocator.invalidateCache()
    }

    @objc private func showAbout() {
        AboutWindowController.shared.show()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        settings.toggleLaunchAtLogin()
        sender.state = launchAtLoginMenuState
    }

    private var launchAtLoginMenuState: NSControl.StateValue {
        switch settings.launchAtLoginStatus {
        case .disabled:
            return .off
        case .enabled:
            return .on
        case .requiresApproval:
            return .mixed
        }
    }

    @objc private func applicationDidResignActive() {
        if pickerWindow?.isVisible == true {
            dismissPicker()
        }
    }

    @objc private func applicationWillTerminate() {
        updateTask?.cancel()
        eventTapController.stop()
        UsageTracker.shared.flushPendingSaves()
    }

    @objc private func checkForUpdates() {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            guard let self else { return }

            do {
                let result = try await updateChecker.check(currentVersion: AppInfo.version)
                guard !Task.isCancelled else { return }
                presentUpdateResult(result)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                presentUpdateError(error)
            }
        }
    }

    private func presentUpdateResult(_ result: UpdateCheckResult) {
        let alert = NSAlert()
        alert.icon = NSImage(named: "Icon") ?? MenuBarIcon.make()
        alert.alertStyle = .informational

        switch result {
        case .upToDate:
            alert.messageText = L10n.string("You're up to date")
            alert.informativeText = L10n.string("No Homebrew update is available.")
            alert.addButton(withTitle: L10n.string("OK"))
            _ = runCenteredAlert(alert)

        case .updateAvailable(let release):
            alert.messageText = L10n.string("Update available")
            alert.informativeText = L10n.format(
                "QuickEmoji %@ is available.\n\nUpdate with Homebrew:\n%@",
                release.version.rawValue,
                AppInfo.homebrewUpgradeCommand
            )
            alert.addButton(withTitle: L10n.string("Copy Command"))
            alert.addButton(withTitle: L10n.string("Open Release Page"))
            alert.addButton(withTitle: L10n.string("Later"))
            switch runCenteredAlert(alert) {
            case .alertFirstButtonReturn:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(AppInfo.homebrewUpgradeCommand, forType: .string)
            case .alertSecondButtonReturn:
                NSWorkspace.shared.open(release.releaseURL)
            default:
                break
            }
        }
    }

    private func presentUpdateError(_ error: Error) {
        let alert = NSAlert()
        alert.icon = NSImage(named: "Icon") ?? MenuBarIcon.make()
        alert.messageText = L10n.string("Couldn't check for updates")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("OK"))
        _ = runCenteredAlert(alert)
    }

    private func runCenteredAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let window = alert.window
        window.contentView?.layoutSubtreeIfNeeded()

        let texts = textFields(in: window.contentView)
        for text in texts where text.stringValue == alert.messageText || text.stringValue == alert.informativeText {
            text.alignment = .center
        }
        return alert.runModal()
    }

    private func textFields(in view: NSView?) -> [NSTextField] {
        guard let view else { return [] }
        return view.subviews.flatMap { subview in
            (subview as? NSTextField).map { [$0] } ?? textFields(in: subview)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

}
