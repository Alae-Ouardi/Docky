import DockyCore
import SwiftUI

/// A shelf in a side dock: drop files on it to move them in, click it to browse.
struct ShelfTileView: View {
    let shelf: Shelf
    let edge: DockEdge
    let iconSize: CGFloat

    @Environment(AppState.self) private var state
    @State private var isTargeted = false
    @State private var isHovered = false

    private var isOpen: Binding<Bool> {
        Binding(
            get: { state.openShelfID == shelf.id },
            set: { open in
                state.openShelfID = open ? shelf.id : nil
                // The docks never take focus; activate so Space / Quick Look reach the popover.
                if open { NSApp.activate() }
            }
        )
    }

    var body: some View {
        Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray.full.fill")
            .font(.system(size: iconSize * 0.5))
            .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
            .frame(width: iconSize, height: iconSize)
            .background(
                RoundedRectangle(cornerRadius: iconSize * 0.22)
                    .fill(Color.primary.opacity(isTargeted || isHovered ? 0.14 : 0.07))
            )
            .scaleEffect(isTargeted ? DockMetrics.hoverScale : 1)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture { isOpen.wrappedValue.toggle() }
            .help(shelf.name)
            .dropDestination(for: URL.self) { urls, _ in
                state.moveFiles(urls.filter(\.isFileURL), to: shelf)
                return true
            } isTargeted: { targeted in
                withAnimation(.spring(duration: 0.2)) { isTargeted = targeted }
            }
            .popover(isPresented: isOpen, arrowEdge: edge == .left ? .trailing : .leading) {
                ShelfContentView(shelf: shelf)
                    .environment(state)
            }
            .contextMenu {
                Button("Open in Finder") { ItemActions.open(shelf.folderURL) }
                Button("Remove Shelf from Dock") { state.removeShelf(shelf, from: edge) }
            }
    }
}
