import AppKit

@MainActor
final class AppContext {
    static let shared = AppContext()

    private(set) var frontmostBundleID: String = ""
    private(set) var frontmostApp: NSRunningApplication?

    nonisolated private static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "dev.warp.Warp-Stable",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
        "io.tabby",
    ]

    nonisolated static func isTerminal(bundleID: String) -> Bool {
        terminalBundleIDs.contains(bundleID)
    }

    private init() {
        if let app = NSWorkspace.shared.frontmostApplication {
            frontmostApp = app
            frontmostBundleID = app.bundleIdentifier ?? ""
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func appDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        frontmostApp = app
        frontmostBundleID = app.bundleIdentifier ?? ""
    }
}
