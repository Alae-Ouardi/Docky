import DockyCore
import SwiftUI

/// Which dock the customization window is editing.
enum DockSelection: Hashable {
    case custom(DockEdge)
    case bottom
}

/// Sidebar of docks (left, top, right and the macOS bottom Dock) with the selected one's settings.
struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var nativeDock: NativeDockEditor
    @State private var selection: DockSelection

    @MainActor
    init(nativeDock: NativeDockEditor? = nil, selection: DockSelection = .custom(.left)) {
        _nativeDock = State(initialValue: nativeDock ?? NativeDockEditor())
        _selection = State(initialValue: selection)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            VStack(spacing: 0) {
                if let error = state.lastError {
                    errorBanner(error)
                }
                detail
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(minWidth: 820, minHeight: 600)
        .task { nativeDock.reload() }
    }

    private var sidebar: some View {
        List(selection: Binding(get: { selection }, set: { if let new = $0 { selection = new } })) {
            Section("Docky") {
                ForEach(DockEdge.allCases, id: \.self) { edge in
                    sidebarRow(
                        title: "\(edge.title) Dock",
                        symbol: edge.symbolName,
                        isOn: state.config[edge].isEnabled
                    )
                    .tag(DockSelection.custom(edge))
                }
            }
            Section("macOS") {
                sidebarRow(title: "Bottom Dock", symbol: "dock.rectangle", isOn: nil)
                    .tag(DockSelection.bottom)
            }
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        .safeAreaInset(edge: .bottom) {
            Toggle("Launch at login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sidebarRow(title: String, symbol: String, isOn: Bool?) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            if let isOn {
                Circle()
                    .fill(isOn ? Color.green : Color.secondary.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .help(isOn ? "On" : "Off")
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .custom(let edge):
            SideDockColumn(edge: edge, nativeDock: nativeDock)
                .id(edge)
        case .bottom:
            NativeDockColumn(editor: nativeDock)
        }
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
