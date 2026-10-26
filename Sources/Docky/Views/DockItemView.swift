import DockyCore
import SwiftUI

/// One pinned app, folder or file in a side dock.
struct DockItemView: View {
    let item: DockItem
    let edge: DockEdge
    let iconSize: CGFloat

    @Environment(AppState.self) private var state
    @State private var isHovered = false

    private var isRunning: Bool { state.running.isRunning(item) }

    var body: some View {
        HStack(spacing: DockMetrics.indicatorGap) {
            if edge == .left { indicator }
            hoverIcon
                .opacity(item.exists ? 1 : 0.35)
            if edge == .right { indicator }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(duration: 0.2)) { isHovered = hovering }
        }
        .onTapGesture { ItemActions.open(item) }
        .help(item.displayName)
        .draggable(DockDragPayload(path: item.path)) { icon }
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
        Button("Move to \(edge.opposite.title) Dock") {
            state.update { $0.moving(itemID: item.id, to: edge.opposite, at: $0[edge.opposite].items.count) }
        }
        Button("Remove from Dock") {
            state.update { $0.removing(itemID: item.id) }
        }
    }
}
