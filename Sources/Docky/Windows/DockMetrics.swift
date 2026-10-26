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

    static func thickness(iconSize: CGFloat) -> CGFloat {
        iconSize + 2 * padding + 2 * (indicatorSize + indicatorGap)
    }

    static func length(for dock: SideDockConfig) -> CGFloat {
        let icon = CGFloat(dock.iconSize)
        var length = 2 * padding + stackLength(count: max(dock.items.count, 1), icon: icon)
        if !dock.shelves.isEmpty {
            length += 2 * spacing + dividerThickness + stackLength(count: dock.shelves.count, icon: icon)
        }
        return length
    }

    private static func stackLength(count: Int, icon: CGFloat) -> CGFloat {
        CGFloat(count) * icon + CGFloat(max(count - 1, 0)) * spacing
    }
}
