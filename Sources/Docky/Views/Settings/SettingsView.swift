import DockyCore
import SwiftUI

/// All four docks side by side, in screen order: left, top, bottom (macOS), right.
/// Items can be dragged between the columns to move them from one dock to another.
struct SettingsView: View {
    static let columnWidth: CGFloat = 300
    static let columnSpacing: CGFloat = 14
    static let padding: CGFloat = 16
    static let minimumWidth = 4 * columnWidth + 3 * columnSpacing + 2 * padding

    @Environment(AppState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            if let error = state.lastError {
                errorBanner(error)
            }
            HStack(alignment: .top, spacing: Self.columnSpacing) {
                SideDockColumn(edge: .left)
                SideDockColumn(edge: .top)
                NativeDockColumn()
                SideDockColumn(edge: .right)
            }
            .padding(Self.padding)
            Divider()
            footer
        }
        .frame(minWidth: Self.minimumWidth, minHeight: 640)
        .task { state.loadBottomDockIfClean() }
    }

    private var footer: some View {
        HStack {
            Toggle("Launch Docky at login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }
            ))
            Spacer()
            Text("Tip: drag items between the columns to move them from one dock to another.")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text(message)
            Spacer()
            Button("Dismiss") { state.lastError = nil }
        }
        .padding(10)
        .background(Color.yellow.opacity(0.15))
    }
}

/// Shared "Add…" picker for apps, folders and files.
@MainActor
enum ItemPicker {
    static func choose() -> [URL] {
        run(prompt: "Add") { panel in
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = true
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
        }
    }

    static func chooseFolder() -> URL? {
        run(prompt: "Use as Shelf") { panel in
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
        }.first
    }

    private static func run(prompt: String, configure: (NSOpenPanel) -> Void) -> [URL] {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.prompt = prompt
        configure(panel)
        return panel.runModal() == .OK ? panel.urls : []
    }
}

/// Placeholder row so an empty list still accepts drops.
struct DropHint: View {
    let onDrop: ([DockDragPayload]) -> Void

    var body: some View {
        Label("Drop apps here", systemImage: "arrow.down.app")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 36)
            .dropDestination(for: DockDragPayload.self) { payloads, _ in
                onDrop(payloads)
                return true
            }
    }
}

/// A list row that can be dragged to another dock's column.
struct DraggableItemRow: View {
    let item: DockItem
    let source: DockID

    var body: some View {
        ItemRow(item: item)
            .draggable(DockDragPayload(item, from: source)) { ItemRow(item: item) }
    }
}

/// A row in any of the settings lists.
struct ItemRow: View {
    let item: DockItem

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: ItemActions.icon(for: item.path))
                .resizable()
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.displayName)
                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .opacity(item.exists ? 1 : 0.4)
    }
}
