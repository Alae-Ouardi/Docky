import DockyCore
import SwiftUI

/// Three columns mirroring the screen: left dock, the native bottom Dock, right dock.
struct SettingsView: View {

    @Environment(AppState.self) private var state
    @State private var nativeDock: NativeDockEditor

    @MainActor
    init(nativeDock: NativeDockEditor? = nil) {
        _nativeDock = State(initialValue: nativeDock ?? NativeDockEditor())
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = state.lastError {
                errorBanner(error)
            }
            HStack(alignment: .top, spacing: 16) {
                SideDockColumn(edge: .left, nativeDock: nativeDock)
                NativeDockColumn(editor: nativeDock)
                SideDockColumn(edge: .right, nativeDock: nativeDock)
            }
            .padding(16)
            Divider()
            footer
        }
        .frame(minWidth: 960, minHeight: 600)
        .task { nativeDock.reload() }
    }

    private var footer: some View {
        HStack {
            Toggle("Launch Docky at login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }
            ))
            Spacer()
            Text("Tip: drag icons between the live docks to rearrange them.")
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
