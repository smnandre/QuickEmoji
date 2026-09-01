import AppKit

enum PanelGeometry {
    static let edgeGap: CGFloat = 8

    static func pickerDefaultFrame(size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let centerY = visibleFrame.maxY - visibleFrame.height * 0.30
        return CGRect(
            x: visibleFrame.midX - size.width / 2,
            y: centerY - size.height / 2,
            width: size.width,
            height: size.height
        )
        .clamped(to: visibleFrame, gap: edgeGap)
    }

    static func isUsableSavedFrame(_ frame: CGRect, visibleFrames: [CGRect]) -> Bool {
        guard frame.width >= PickerGeometry.minimumSize.width,
            frame.height >= PickerGeometry.minimumSize.height,
            frame.width <= PickerGeometry.maximumSize.width,
            frame.height <= PickerGeometry.maximumSize.height
        else {
            return false
        }

        return visibleFrames.contains { visibleFrame in
            visibleFrame.insetBy(dx: -edgeGap, dy: -edgeGap).contains(frame.center)
                && frame.intersection(visibleFrame).width >= min(frame.width, visibleFrame.width) * 0.6
                && frame.intersection(visibleFrame).height >= min(frame.height, visibleFrame.height) * 0.6
        }
    }
}

enum PickerGeometry {
    static let visibleColumnLimit = 5
    static let visibleRowLimit = 2
    static let cellSize: CGFloat = 46
    static let cellSpacing: CGFloat = 8
    static let outerPadding: CGFloat = 12
    static let gridPadding: CGFloat = 6
    static let searchFieldHeight: CGFloat = 44
    static let searchBottomSpacing: CGFloat = 10
    static let horizontalChrome: CGFloat = outerPadding * 2 + gridPadding * 2
    static let defaultSize = panelSize()
    static let minimumSize = defaultSize
    static let maximumSize = defaultSize

    static func gridWidth() -> CGFloat {
        CGFloat(visibleColumnLimit) * cellSize + CGFloat(visibleColumnLimit - 1) * cellSpacing
    }

    static func gridHeight(rows: Int) -> CGFloat {
        CGFloat(rows) * cellSize + CGFloat(max(0, rows - 1)) * cellSpacing
    }

    static func gridViewportHeight(visibleRows: Int) -> CGFloat {
        gridHeight(rows: visibleRows) + gridPadding * 2
    }

    static func panelSize() -> CGSize {
        CGSize(
            width: gridWidth() + horizontalChrome,
            height: outerPadding * 2
                + searchFieldHeight
                + searchBottomSpacing
                + gridViewportHeight(visibleRows: visibleRowLimit)
        )
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    func clamped(to visibleFrame: CGRect, gap: CGFloat) -> CGRect {
        let clampedWidth = min(width, visibleFrame.width - gap * 2)
        let clampedHeight = min(height, visibleFrame.height - gap * 2)
        let clampedX = max(
            visibleFrame.minX + gap,
            min(origin.x, visibleFrame.maxX - clampedWidth - gap)
        )
        let clampedY = max(
            visibleFrame.minY + gap,
            min(origin.y, visibleFrame.maxY - clampedHeight - gap)
        )
        return CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }
}
