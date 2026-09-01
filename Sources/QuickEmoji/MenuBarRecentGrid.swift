import AppKit

@MainActor
enum MenuBarRecentGrid {
    nonisolated static let columns = 6
    nonisolated static let rows = 2
    nonisolated static let cell: CGFloat = 30
    nonisolated static let spacing: CGFloat = 6
    static let minimumHorizontalPadding: CGFloat = 17.5
    static let vPadding: CGFloat = 6

    static var capacity: Int { columns * rows }

    static var contentWidth: CGFloat {
        CGFloat(columns) * cell + CGFloat(columns - 1) * spacing
    }

    static var minimumWidth: CGFloat {
        contentWidth + minimumHorizontalPadding * 2
    }

    nonisolated static func horizontalInset(for containerWidth: CGFloat) -> CGFloat {
        max((containerWidth - (CGFloat(columns) * cell + CGFloat(columns - 1) * spacing)) / 2, 0)
    }

    static func makeView(
        entries: [PickerEntry],
        onCopy: @escaping (PickerEntry) -> Void,
        onRemove: @escaping (PickerEntry) -> Void,
        closeMenu: @escaping () -> Void
    ) -> NSView {
        let width = minimumWidth
        let height = CGFloat(rows) * cell + CGFloat(rows - 1) * spacing + vPadding * 2
        return MenuRecentGridView(
            frame: NSRect(x: 0, y: 0, width: width, height: height),
            entries: entries,
            onCopy: onCopy,
            onRemove: onRemove,
            closeMenu: closeMenu
        )
    }
}

private final class MenuRecentGridView: NSView {
    private let cells: [MenuEmojiCellView]

    init(
        frame: NSRect,
        entries: [PickerEntry],
        onCopy: @escaping (PickerEntry) -> Void,
        onRemove: @escaping (PickerEntry) -> Void,
        closeMenu: @escaping () -> Void
    ) {
        self.cells = entries.prefix(MenuBarRecentGrid.capacity).map { entry in
            MenuEmojiCellView(
                entry: entry,
                onCopy: {
                    onCopy(entry); closeMenu()
                },
                onRemove: {
                    onRemove(entry); closeMenu()
                }
            )
        }
        super.init(frame: frame)
        cells.forEach(addSubview)
        layoutCells()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        layoutCells()
    }

    private func layoutCells() {
        let xInset = MenuBarRecentGrid.horizontalInset(for: bounds.width)
        for (index, cell) in cells.enumerated() {
            let column = index % MenuBarRecentGrid.columns
            let row = index / MenuBarRecentGrid.columns
            let x = xInset + CGFloat(column) * (MenuBarRecentGrid.cell + MenuBarRecentGrid.spacing)
            let y =
                bounds.height - MenuBarRecentGrid.vPadding - MenuBarRecentGrid.cell
                - CGFloat(row) * (MenuBarRecentGrid.cell + MenuBarRecentGrid.spacing)
            cell.frame = NSRect(
                x: x,
                y: y,
                width: MenuBarRecentGrid.cell,
                height: MenuBarRecentGrid.cell
            )
        }
    }
}

private final class MenuEmojiCellView: NSView {
    private let entry: PickerEntry
    private let onCopy: () -> Void
    private let onRemove: () -> Void
    private var hovered = false {
        didSet { needsDisplay = true }
    }

    init(entry: PickerEntry, onCopy: @escaping () -> Void, onRemove: @escaping () -> Void) {
        self.entry = entry
        self.onCopy = onCopy
        self.onRemove = onRemove
        super.init(frame: .zero)
        wantsLayer = true
        toolTip = entry.name
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            ))
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
    }

    override func draw(_ dirtyRect: NSRect) {
        if hovered {
            let path = NSBezierPath(
                roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                xRadius: 7,
                yRadius: 7
            )
            NSColor.labelColor.withAlphaComponent(0.10).setFill()
            path.fill()
        }

        let glyph = NSAttributedString(
            string: entry.character,
            attributes: [.font: NSFont.systemFont(ofSize: 18)]
        )
        let size = glyph.size()
        glyph.draw(
            at: NSPoint(
                x: (bounds.width - size.width) / 2,
                y: (bounds.height - size.height) / 2
            ))
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            onRemove()
            return
        }
        onCopy()
    }

    override func rightMouseDown(with event: NSEvent) {
        onRemove()
    }
}
