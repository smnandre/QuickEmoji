import AppKit
import SwiftUI

@MainActor
@Observable
final class PickerViewModel {
    var query = "" {
        didSet {
            isAllSearchTextSelected = false
            guard query != oldValue else { return }
            refreshResults()
        }
    }
    var results: [PickerEntry]
    var selectedIndex = 0
    var hoveredID: PickerEntry.ID?
    var searchFocusRequest = 0
    var selectAllRequest = 0
    private(set) var isAllSearchTextSelected = false
    var copiedEntryID: PickerEntry.ID?
    var confirmingEntryID: PickerEntry.ID?

    let bundleID: String
    let onSelect: (String, Bool) -> Void
    let onDismiss: () -> Void

    init(
        bundleID: String,
        onSelect: @escaping (String, Bool) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.bundleID = bundleID
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        self.query = ""
        self.results = Self.results(query: "", bundleID: bundleID)
    }

    var activeEntry: PickerEntry? {
        if let hoveredID, let entry = results.first(where: { $0.id == hoveredID }) {
            return entry
        }
        return selectedEntry
    }

    var selectedEntry: PickerEntry? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        let nextIndex = Self.clampedSelection(
            current: selectedIndex,
            delta: delta,
            count: results.count
        )
        guard nextIndex != selectedIndex else { return }
        selectedIndex = nextIndex
    }

    func moveLeft() {
        moveSelection(-1)
    }

    func moveRight() {
        moveSelection(1)
    }

    func moveUp() {
        moveSelection(-PickerGeometry.visibleColumnLimit)
    }

    func moveDown() {
        moveSelection(PickerGeometry.visibleColumnLimit)
    }

    func selectCurrent(keepOpen: Bool = false) {
        guard let entry = selectedEntry else { return }
        select(entry, keepOpen: keepOpen)
    }

    func select(_ entry: PickerEntry, keepOpen: Bool = false) {
        confirmingEntryID = entry.id
        EmojiSearch.shared.recordUsage(entry, bundleID: bundleID)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { [weak self] in
            self?.onSelect(entry.character, keepOpen)
            guard self?.confirmingEntryID == entry.id else { return }
            self?.confirmingEntryID = nil
        }
    }

    func copy(_ entry: PickerEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.character, forType: .string)
        copiedEntryID = entry.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard self?.copiedEntryID == entry.id else { return }
            self?.copiedEntryID = nil
        }
    }

    func copyFromMenu(_ entry: PickerEntry) {
        copy(entry)
        EmojiSearch.shared.recordUsage(entry, bundleID: bundleID)
    }

    func removeFromRecent(_ entry: PickerEntry) {
        UsageTracker.shared.remove(character: entry.character)
        refreshResults()
    }

    func isRecent(_ entry: PickerEntry) -> Bool {
        UsageTracker.shared.contains(character: entry.character)
    }

    func appendSearchText(_ text: String) {
        if isAllSearchTextSelected {
            query = text
        } else {
            query += text
        }
        isAllSearchTextSelected = false
    }

    func deleteBackwardInSearch() {
        guard !query.isEmpty else { return }
        if isAllSearchTextSelected {
            query = ""
            isAllSearchTextSelected = false
            return
        }
        query.removeLast()
    }

    func requestSearchFocus() {
        searchFocusRequest += 1
    }

    func requestSelectAll() {
        selectAllRequest += 1
        isAllSearchTextSelected = !query.isEmpty
    }

    func handleEscape() {
        if !query.isEmpty {
            query = ""
            return
        }

        onDismiss()
    }

    nonisolated static func clampedSelection(current: Int, delta: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return max(0, min(count - 1, current + delta))
    }

    private func refreshResults() {
        results = Self.results(query: query, bundleID: bundleID)
        selectedIndex = 0
        hoveredID = nil
        confirmingEntryID = nil
    }

    static func results(
        query: String,
        bundleID: String,
        searchLimit: Int = 50
    ) -> [PickerEntry] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.isEmpty
            ? EmojiSearch.shared.defaultEntries(bundleID: bundleID)
            : EmojiSearch.shared.search(trimmedQuery, limit: searchLimit, bundleID: bundleID)
    }
}

struct PickerContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    var viewModel: PickerViewModel

    @FocusState private var searchFocused: Bool
    @State private var searchSelection: TextSelection?

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 0) {
                searchField
                gridContent
            }
            .padding(PickerGeometry.outerPadding)
            .background(
                Color(nsColor: .windowBackgroundColor),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { searchFocused = true }
        .onChange(of: viewModel.searchFocusRequest) {
            searchFocused = true
        }
        .onChange(of: viewModel.selectAllRequest) {
            searchFocused = true
            searchSelection = TextSelection(
                range: viewModel.query.startIndex..<viewModel.query.endIndex
            )
        }
        .onKeyPress(.upArrow) {
            viewModel.moveUp()
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.moveDown()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.moveLeft()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.moveRight()
            return .handled
        }
        .onKeyPress(.escape) {
            viewModel.handleEscape()
            return .handled
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            SearchIcon()
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.9) : Color.black.opacity(0.72),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                )
                .frame(width: 13, height: 13)

            TextField(
                L10n.string("Search…"),
                text: Binding(
                    get: { viewModel.query },
                    set: { viewModel.query = $0 }
                ),
                selection: $searchSelection
            )
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .focused($searchFocused)
            .onSubmit { viewModel.selectCurrent() }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: PickerGeometry.searchFieldHeight)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.bottom, PickerGeometry.searchBottomSpacing)
    }

    private var gridContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: fullPickerColumns, spacing: PickerGeometry.cellSpacing) {
                    ForEach(viewModel.results) { entry in
                        EmojiTileView(
                            entry: entry,
                            isActive: viewModel.activeEntry?.id == entry.id,
                            isCopied: viewModel.copiedEntryID == entry.id,
                            isConfirming: viewModel.confirmingEntryID == entry.id,
                            onSelect: { viewModel.select(entry) },
                            onCopy: { viewModel.copyFromMenu(entry) },
                            onRemove: { viewModel.removeFromRecent(entry) },
                            canRemove: { viewModel.isRecent(entry) }
                        )
                        .id(entry.id)
                        .onHover { hovering in
                            DispatchQueue.main.async {
                                if hovering {
                                    viewModel.hoveredID = entry.id
                                } else if viewModel.hoveredID == entry.id {
                                    viewModel.hoveredID = nil
                                }
                            }
                        }
                    }
                }
                .padding(PickerGeometry.gridPadding)
            }
            .frame(
                width: PickerGeometry.gridWidth() + PickerGeometry.gridPadding * 2,
                height: PickerGeometry.gridViewportHeight(visibleRows: PickerGeometry.visibleRowLimit)
            )
            .onChange(of: viewModel.selectedIndex) { _, idx in
                if idx < viewModel.results.count {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(viewModel.results[idx].id)
                    }
                }
            }
        }
    }

    private var fullPickerColumns: [GridItem] {
        return Array(
            repeating: GridItem(.fixed(PickerGeometry.cellSize), spacing: PickerGeometry.cellSpacing),
            count: PickerGeometry.visibleColumnLimit
        )
    }
}

private struct SearchIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let diameter = min(rect.width, rect.height) * 0.68
        path.addEllipse(
            in: CGRect(
                x: rect.minX,
                y: rect.minY,
                width: diameter,
                height: diameter
            )
        )
        path.move(to: CGPoint(x: rect.minX + diameter * 0.78, y: rect.minY + diameter * 0.78))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

private struct EmojiTileView: View {
    let entry: PickerEntry
    let isActive: Bool
    let isCopied: Bool
    let isConfirming: Bool
    let onSelect: () -> Void
    let onCopy: () -> Void
    let onRemove: () -> Void
    let canRemove: () -> Bool

    var body: some View {
        ZStack {
            emojiLabel
                .scaleEffect(isConfirming ? 0.93 : 1)
                .animation(.spring(response: 0.18, dampingFraction: 0.62), value: isConfirming)

            if isConfirming {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 24, height: 24)
                    .glassEffect(.regular.interactive(), in: Circle())
            }

            MouseClickCaptureView(
                onSelect: onSelect,
                contextMenu: EmojiTileContextMenu(
                    title: entry.name,
                    onCopy: onCopy,
                    onRemove: onRemove,
                    canRemove: canRemove
                )
            )
            .frame(width: tileSize, height: tileSize)

            if isCopied {
                CopiedPill()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: tileSize, height: tileSize)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? Color.primary.opacity(0.1) : .clear)
                .padding(4)
        }
        .animation(.easeOut(duration: 0.12), value: isActive)
        .contentShape(Rectangle())
    }

    private var emojiLabel: some View {
        Text(entry.character)
            .font(.system(size: 27))
            .frame(width: tileSize, height: tileSize)
    }

    private var tileSize: CGFloat {
        PickerGeometry.cellSize
    }

}

private struct CopiedPill: View {
    @State private var lifted = false

    var body: some View {
        Text(L10n.string("Copied"))
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(Color.green.opacity(0.92)))
            .fixedSize()
            .scaleEffect(lifted ? 1.12 : 0.82)
            .offset(y: lifted ? -20 : -2)
            .opacity(lifted ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45)) {
                    lifted = true
                }
            }
    }
}

private struct EmojiTileContextMenu {
    let title: String
    let onCopy: () -> Void
    let onRemove: () -> Void
    let canRemove: () -> Bool
}

private struct MouseClickCaptureView: NSViewRepresentable {
    let onSelect: () -> Void
    let contextMenu: EmojiTileContextMenu

    func makeNSView(context: Context) -> ClickCaptureNSView {
        ClickCaptureNSView(onSelect: onSelect, contextMenu: contextMenu)
    }

    func updateNSView(_ nsView: ClickCaptureNSView, context: Context) {
        nsView.onSelect = onSelect
        nsView.contextMenu = contextMenu
        nsView.setAccessibilityLabel(contextMenu.title)
    }

    final class ClickCaptureNSView: NSView {
        var onSelect: () -> Void
        var contextMenu: EmojiTileContextMenu

        init(onSelect: @escaping () -> Void, contextMenu: EmojiTileContextMenu) {
            self.onSelect = onSelect
            self.contextMenu = contextMenu
            super.init(frame: .zero)
            setAccessibilityElement(true)
            setAccessibilityRole(.button)
            setAccessibilityLabel(contextMenu.title)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func mouseDown(with event: NSEvent) {
            if event.modifierFlags.contains(.control) {
                presentContextMenu(with: event)
                return
            }
            onSelect()
        }

        override func rightMouseDown(with event: NSEvent) {
            presentContextMenu(with: event)
        }

        override func accessibilityPerformPress() -> Bool {
            onSelect()
            return true
        }

        private func presentContextMenu(with event: NSEvent) {
            let menu = NSMenu()
            menu.autoenablesItems = false

            let name = contextMenu.title
            let displayTitle = name.isEmpty ? name : name.prefix(1).uppercased() + name.dropFirst()
            menu.addItem(.sectionHeader(title: displayTitle))

            let copyItem = NSMenuItem(
                title: L10n.string("Copy Emoji"), action: #selector(handleCopy), keyEquivalent: "")
            copyItem.target = self
            menu.addItem(copyItem)

            menu.addItem(.separator())
            let removeItem = NSMenuItem(
                title: L10n.string("Remove from Recent"), action: #selector(handleRemove), keyEquivalent: "")
            removeItem.target = self
            removeItem.isEnabled = contextMenu.canRemove()
            menu.addItem(removeItem)

            let location = convert(event.locationInWindow, from: nil)
            menu.popUp(positioning: nil, at: location, in: self)
        }

        @objc private func handleCopy() { contextMenu.onCopy() }
        @objc private func handleRemove() { contextMenu.onRemove() }
    }
}
