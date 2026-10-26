import DockyCore
import SwiftUI

/// Vertical stack of pinned items with the shelves underneath.
struct DockView: View {
    let edge: DockEdge
    @Environment(AppState.self) private var state
    @State private var dropTargetIndex: Int?

    private var side: SideDockConfig { state.config[edge] }
    private var iconSize: CGFloat { side.iconSize }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DockMetrics.spacing) {
                if side.items.isEmpty {
                    placeholder
                }
                ForEach(Array(side.items.enumerated()), id: \.element.id) { index, item in
                    DockItemView(item: item, edge: edge, iconSize: iconSize)
                        .overlay(alignment: .top) { insertionMarker(visible: dropTargetIndex == index) }
                        .dropDestination(for: DockDragPayload.self) { payloads, _ in
                            state.drop(payloads.map(\.url), on: edge, at: index)
                            return true
                        } isTargeted: { targeted in
                            if targeted {
                                dropTargetIndex = index
                            } else if dropTargetIndex == index {
                                dropTargetIndex = nil
                            }
                        }
                }
                if !side.shelves.isEmpty {
                    Divider()
                        .frame(width: iconSize * 0.7, height: DockMetrics.dividerHeight)
                    ForEach(side.shelves) { shelf in
                        ShelfTileView(shelf: shelf, edge: edge, iconSize: iconSize)
                    }
                }
            }
            .padding(DockMetrics.padding)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .dropDestination(for: DockDragPayload.self) { payloads, _ in
            state.drop(payloads.map(\.url), on: edge, at: nil)
            return true
        }
    }

    private var placeholder: some View {
        Image(systemName: "plus.square.dashed")
            .font(.system(size: iconSize * 0.6, weight: .light))
            .foregroundStyle(.secondary)
            .frame(width: iconSize, height: iconSize)
            .help("Drag apps, folders or files here")
    }

    private func insertionMarker(visible: Bool) -> some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(width: iconSize, height: 3)
            .offset(y: -DockMetrics.spacing / 2 - 1.5)
            .opacity(visible ? 1 : 0)
    }
}
