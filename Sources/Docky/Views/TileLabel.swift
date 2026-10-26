import SwiftUI

/// The name shown under a folder or shelf icon. One line, truncated to the tile's width;
/// the full name stays in the tile's tooltip.
struct TileLabel: View {
    let text: String
    let iconSize: CGFloat
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: DockMetrics.labelFontSize(iconSize: iconSize)))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: width, height: DockMetrics.labelHeight(iconSize: iconSize))
    }
}
