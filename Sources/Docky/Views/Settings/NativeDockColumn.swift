import DockyCore
import SwiftUI

/// Edits the pinned items of the native macOS Dock. Nothing changes until "Apply".
struct NativeDockColumn: View {
    @Environment(AppState.self) private var state
    @State private var isConfirming = false

    private var editor: NativeDockEditor { state.nativeDock }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Finder and Trash are always shown by macOS and are not listed here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if editor.isDirty {
                    Label("Unapplied changes. Press Apply to Dock to update the macOS Dock.", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                List {
                    section("Apps", .apps)
                    section("Folders & Files", .others)
                }
                .frame(minHeight: 360)

                HStack {
                    Button("Add…") { editor.add(ItemPicker.choose()) }
                    Button("Revert") { state.revertBottomDock() }
                        .disabled(!editor.isDirty)
                    Spacer()
                    Button("Apply to Dock") { isConfirming = true }
                        .buttonStyle(.borderedProminent)
                        // Never write an empty Dock: that is almost certainly a read failure.
                        .disabled(!editor.isDirty || editor.draft.isEmpty)
                }
                if let backup = editor.lastBackup {
                    HStack {
                        Text("Previous Dock was backed up.").font(.caption).foregroundStyle(.secondary)
                        Button("Undo") { state.undoBottomDock(backup) }
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                }
            }
        } label: {
            Label("Bottom Dock (macOS)", systemImage: "dock.rectangle")
                .font(.headline)
        }
        .confirmationDialog("Apply changes to the macOS Dock?", isPresented: $isConfirming) {
            Button("Apply and Restart Dock") { state.applyBottomDock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Dock restarts briefly. A backup of your current Dock is saved first.")
        }
        .frame(minWidth: SettingsView.columnWidth)
    }

    private func section(_ title: String, _ section: NativeDockLayout.Section) -> some View {
        let items = editor.draft[section]
        return Section(title) {
            if items.isEmpty {
                DropHint { state.move($0, to: .bottom(section), at: nil) }
            }
            ForEach(items) { item in
                DraggableItemRow(item: item, source: .bottom)
                    .contextMenu { rowMenu(for: item) }
            }
            .dropDestination(for: DockDragPayload.self) { payloads, index in
                state.move(payloads, to: .bottom(section), at: index)
            }
        }
    }

    @ViewBuilder
    private func rowMenu(for item: DockItem) -> some View {
        ForEach(DockEdge.allCases, id: \.self) { edge in
            Button("Move to \(edge.title) Dock") {
                state.move([DockDragPayload(item, from: .bottom)], to: .custom(edge), at: nil)
            }
        }
        Button("Show in Finder") { ItemActions.revealInFinder(item.url) }
        Divider()
        Button("Remove", role: .destructive) { editor.remove(paths: [item.path]) }
    }
}
