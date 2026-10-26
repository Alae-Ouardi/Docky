import DockyCore
import SwiftUI

/// Edits the pinned items of the native macOS Dock. Nothing changes until "Apply".
struct NativeDockColumn: View {
    @Bindable var editor: NativeDockEditor

    @Environment(AppState.self) private var state
    @State private var isConfirming = false

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Finder and Trash are always shown by macOS and are not listed here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List {
                    Section("Apps") {
                        ForEach(editor.draft.apps) { item in
                            ItemRow(item: item).contextMenu { rowMenu(for: item) }
                        }
                        .onMove { editor.move(\.apps, from: $0, to: $1) }
                    }
                    Section("Folders & Files") {
                        ForEach(editor.draft.others) { item in
                            ItemRow(item: item).contextMenu { rowMenu(for: item) }
                        }
                        .onMove { editor.move(\.others, from: $0, to: $1) }
                    }
                }
                .frame(minHeight: 360)
                .dropDestination(for: DockDragPayload.self) { payloads, _ in
                    editor.add(payloads.map(\.url))
                    return true
                }

                HStack {
                    Button("Add…") { editor.add(ItemPicker.choose()) }
                    Button("Revert") { editor.reload() }
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
                        Button("Undo") { restore(backup) }
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
            Button("Apply and Restart Dock") { apply() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The Dock restarts briefly. A backup of your current Dock is saved first.")
        }
    }

    @ViewBuilder
    private func rowMenu(for item: DockItem) -> some View {
        ForEach(DockEdge.allCases, id: \.self) { edge in
            Button("Move to \(edge.title) Dock") {
                state.drop([item.url], on: edge, at: nil)
                editor.remove(item)
            }
        }
        Button("Show in Finder") { ItemActions.revealInFinder(item.url) }
        Divider()
        Button("Remove", role: .destructive) { editor.remove(item) }
    }

    private func restore(_ backup: URL) {
        do {
            try editor.restore(backup)
        } catch {
            state.report(error.localizedDescription, error)
        }
    }

    private func apply() {
        do {
            try editor.apply()
        } catch {
            state.report(error.localizedDescription, error)
        }
    }
}
