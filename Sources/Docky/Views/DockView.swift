import DockyCore
import SwiftUI

/// The pinned items of one dock followed by its shelves: a column for side docks,
/// a row for the top dock.
struct DockView: View {
    let edge: DockEdge
    @Environment(AppState.self) private var state
    @State private var dropTargetIndex: Int?

    private var dock: SideDockConfig { state.config[edge] }
    private var iconSize: CGFloat { dock.iconSize }

    private var stack: AnyLayout {
        edge.isHorizontal
            ? AnyLayout(HStackLayout(spacing: DockMetrics.spacing))
            : AnyLayout(VStackLayout(spacing: DockMetrics.spacing))
    }

    var body: some View {
        ScrollView(edge.isHorizontal ? .horizontal : .vertical, showsIndicators: false) {
            stack {
                if dock.items.isEmpty {
                    placeholder
                }
                ForEach(Array(dock.items.enumerated()), id: \.element.id) { index, item in
                    DockItemView(item: item, edge: edge, iconSize: iconSize)
                        .overlay(alignment: edge.isHorizontal ? .leading : .top) {
                            insertionMarker(visible: dropTargetIndex == index)
                        }
                        .dropDestination(for: DockDragPayload.self) { payloads, _ in
                            state.move(payloads, to: .custom(edge), at: index)
                            return true
                        } isTargeted: { targeted in
                            if targeted {
                                dropTargetIndex = index
                            } else if dropTargetIndex == index {
                                dropTargetIndex = nil
                            }
                        }
                }
                if !dock.shelves.isEmpty {
                    divider
                    ForEach(dock.shelves) { shelf in
                        ShelfTileView(shelf: shelf, edge: edge, iconSize: iconSize)
                    }
                }
            }
            .padding(DockMetrics.padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .dropDestination(for: DockDragPayload.self) { payloads, _ in
            state.move(payloads, to: .custom(edge), at: nil)
            return true
        }
    }

    private var divider: some View {
        Divider()
            .frame(
                width: edge.isHorizontal ? DockMetrics.dividerThickness : iconSize * 0.7,
                height: edge.isHorizontal ? iconSize * 0.7 : DockMetrics.dividerThickness
            )
    }

    private var placeholder: some View {
        Image(systemName: "plus.square.dashed")
            .font(.system(size: iconSize * 0.6, weight: .light))
            .foregroundStyle(.secondary)
            .frame(width: iconSize, height: iconSize)
            .help("Drag apps, folders or files here")
    }

    private func insertionMarker(visible: Bool) -> some View {
        let offset = -DockMetrics.spacing / 2 - 1.5
        return Capsule()
            .fill(Color.accentColor)
            .frame(width: edge.isHorizontal ? 3 : iconSize, height: edge.isHorizontal ? iconSize : 3)
            .offset(x: edge.isHorizontal ? offset : 0, y: edge.isHorizontal ? 0 : offset)
            .opacity(visible ? 1 : 0)
    }
}
