import CoreGraphics
import DockyCore

/// Shared sizes so the window frame and the SwiftUI layout always agree.
/// "Thickness" runs across the dock (away from the screen edge), "length" along it.
enum DockMetrics {
    static let padding: CGFloat = 8
    static let spacing: CGFloat = 6
    static let indicatorSize: CGFloat = 4
    static let indicatorGap: CGFloat = 3
    static let dividerThickness: CGFloat = 9
    static let screenMargin: CGFloat = 12
    static let cornerRadius: CGFloat = 16
    static let hoverScale: CGFloat = 1.12
    static let labelGap: CGFloat = 2

    /// Folder and shelf names scale with the icon but stay readable at the extremes.
    static func labelFontSize(iconSize: CGFloat) -> CGFloat {
        min(max(iconSize * 0.2, 9), 13)
    }

    /// Fixed so the window frame can reserve exactly the space the label takes.
    static func labelHeight(iconSize: CGFloat) -> CGFloat {
        (labelFontSize(iconSize: iconSize) * 1.3).rounded(.up)
    }

    /// Room a label adds below its icon, gap included.
    static func labelSpace(iconSize: CGFloat) -> CGFloat {
        labelGap + labelHeight(iconSize: iconSize)
    }

    static func thickness(for dock: SideDockConfig, edge: DockEdge) -> CGFloat {
        let icon = CGFloat(dock.iconSize)
        var thickness = icon + 2 * padding + 2 * (indicatorSize + indicatorGap)
        // A row of icons grows across the dock when any of them carries a label.
        if edge.isHorizontal && dock.labeledTileCount > 0 {
            thickness += labelSpace(iconSize: icon)
        }
        return thickness
    }

    static func length(for dock: SideDockConfig, edge: DockEdge) -> CGFloat {
        let icon = CGFloat(dock.iconSize)
        var length = 2 * padding + stackLength(count: max(dock.items.count, 1), icon: icon)
        if !dock.shelves.isEmpty {
            length += 2 * spacing + dividerThickness + stackLength(count: dock.shelves.count, icon: icon)
        }
        // A column grows along the dock by one label per labeled tile.
        if !edge.isHorizontal {
            length += CGFloat(dock.labeledTileCount) * labelSpace(iconSize: icon)
        }
        return length
    }

    private static func stackLength(count: Int, icon: CGFloat) -> CGFloat {
        CGFloat(count) * icon + CGFloat(max(count - 1, 0)) * spacing
    }
}
