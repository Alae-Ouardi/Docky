import CoreGraphics
import DockyCore

/// Shared sizes so the window frame and the SwiftUI layout always agree.
enum DockMetrics {
    static let padding: CGFloat = 8
    static let spacing: CGFloat = 6
    static let indicatorSize: CGFloat = 4
    static let indicatorGap: CGFloat = 3
    static let dividerHeight: CGFloat = 9
    static let screenMargin: CGFloat = 12
    static let cornerRadius: CGFloat = 16
    static let hoverScale: CGFloat = 1.12

    static func width(iconSize: CGFloat) -> CGFloat {
        iconSize + 2 * padding + 2 * (indicatorSize + indicatorGap)
    }

    static func contentHeight(for side: SideDockConfig) -> CGFloat {
        let icon = CGFloat(side.iconSize)
        let itemRows = max(side.items.count, 1)
        var height = 2 * padding + stackHeight(rows: itemRows, icon: icon)
        if !side.shelves.isEmpty {
            height += dividerHeight + spacing + stackHeight(rows: side.shelves.count, icon: icon)
        }
        return height
    }

    private static func stackHeight(rows: Int, icon: CGFloat) -> CGFloat {
        CGFloat(rows) * icon + CGFloat(max(rows - 1, 0)) * spacing
    }
}
