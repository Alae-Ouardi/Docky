import DockyCore
import SwiftUI

/// One pinned app, folder or file in a dock. The running dot sits on the screen-edge side.
struct DockItemView: View {
    let item: DockItem
    let edge: DockEdge
    let iconSize: CGFloat

    @Environment(AppState.self) private var state
    @State private var isHovered = false

    private var isRunning: Bool { state.running.isRunning(item) }

    private var stack: AnyLayout {
        edge.isHorizontal
            ? AnyLayout(VStackLayout(spacing: DockMetrics.indicatorGap))
            : AnyLayout(HStackLayout(spacing: DockMetrics.indicatorGap))
    }

    /// Side docks let the label span the indicator column too; a row keeps it to the icon.
    private var labelWidth: CGFloat {
        edge.isHorizontal ? iconSize : iconSize + DockMetrics.indicatorSize + DockMetrics.indicatorGap
    }

    var body: some View {
        VStack(spacing: DockMetrics.labelGap) {
            stack {
                if edge != .right { indicator }
                hoverIcon
                    .opacity(item.exists ? 1 : 0.35)
                if edge == .right { indicator }
            }
            if item.kind == .folder {
                TileLabel(text: item.displayName, iconSize: iconSize, width: labelWidth)
                    .opacity(item.exists ? 1 : 0.35)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(duration: 0.2)) { isHovered = hovering }
        }
        .onTapGesture { ItemActions.open(item) }
        .help(item.displayName)
        .draggable(DockDragPayload(item, from: .custom(edge))) { icon }
        .contextMenu {
            Button("Open") { ItemActions.open(item) }
            if isRunning {
                Button("Quit") { state.running.application(for: item)?.terminate() }
            }
            ItemMenu(item: item, edge: edge)
        }
    }

    private var icon: some View {
        iconImage(size: iconSize)
    }

    /// Drawn at the enlarged size and scaled *down* when idle: scaling a bitmap up is what made
    /// the hovered icon blurry, scaling down keeps it sharp. The outer frame keeps the layout.
    private var hoverIcon: some View {
        let zoomed = iconSize * DockMetrics.hoverScale
        return iconImage(size: zoomed)
            .scaleEffect(isHovered ? 1 : 1 / DockMetrics.hoverScale)
            .frame(width: iconSize, height: iconSize)
    }

    private func iconImage(size: CGFloat) -> some View {
        Image(nsImage: ItemActions.icon(for: item.path))
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .frame(width: size, height: size)
    }

    private var indicator: some View {
        Circle()
            .fill(isRunning ? Color.primary.opacity(0.75) : .clear)
            .frame(width: DockMetrics.indicatorSize, height: DockMetrics.indicatorSize)
    }
}

/// Context-menu entries shared by the live docks and the settings lists.
struct ItemMenu: View {
    let item: DockItem
    let edge: DockEdge

    @Environment(AppState.self) private var state

    var body: some View {
        Button("Show in Finder") { ItemActions.revealInFinder(item.url) }
        Divider()
        ForEach(DockEdge.allCases.filter { $0 != edge }, id: \.self) { target in
            Button("Move to \(target.title) Dock") {
                state.move([DockDragPayload(item, from: .custom(edge))], to: .custom(target), at: nil)
            }
        }
        Button("Remove from Dock") {
            state.update { $0.removing(itemID: item.id) }
        }
    }
}
