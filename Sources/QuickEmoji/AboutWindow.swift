import AppKit
import SwiftUI

struct AboutView: View {
    let icon: NSImage
    let version: String

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 5, y: 2)

            VStack(spacing: 3) {
                Text("QUICK EMOJI")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(.primary)
                Text("v\(version)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 2) {
                Text("Simon André")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Link("smnand.re/quickemoji", destination: AppInfo.websiteURL)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 34)
        .padding(.vertical, 28)
        .frame(width: 260)
    }
}

private final class AboutWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown, event.keyCode == 53 else {
            super.sendEvent(event)
            return
        }
        close()
    }
}

@MainActor
final class AboutWindowController {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let icon = NSImage(named: "Icon") ?? NSApp.applicationIconImage ?? NSImage()
        let view = AboutView(icon: icon, version: AppInfo.version)

        let hosting = NSHostingView(rootView: view)
        hosting.setFrameSize(hosting.fittingSize)

        let window = AboutWindow(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: hosting.fittingSize))
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 24
        visualEffect.layer?.masksToBounds = true

        hosting.frame = visualEffect.bounds
        hosting.autoresizingMask = [.width, .height]
        visualEffect.addSubview(hosting)
        window.contentView = visualEffect
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
