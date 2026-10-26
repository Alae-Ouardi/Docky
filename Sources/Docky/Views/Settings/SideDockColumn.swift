import DockyCore
import SwiftUI

/// Settings for one side dock: on/off, visibility, icon size, items and shelves.
struct SideDockColumn: View {
    let edge: DockEdge
    let nativeDock: NativeDockEditor

    @Environment(AppState.self) private var state
    @State private var newShelfName = ""

    private var side: SideDockConfig { state.config[edge] }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Show \(edge.title.lowercased()) dock", isOn: binding(\.isEnabled))
                    .toggleStyle(.switch)

                Picker("Visibility", selection: binding(\.visibility)) {
                    Text("Always visible").tag(DockVisibility.alwaysVisible)
                    Text("Show at screen edge").tag(DockVisibility.autoHide)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                HStack {
                    Text("Icon size")
                    Slider(value: binding(\.iconSize), in: SideDockConfig.iconSizeRange, step: 4)
                    Text("\(Int(side.iconSize))").monospacedDigit().frame(width: 28)
                }

                itemsList
                shelvesSection
            }
        } label: {
            Label("\(edge.title) Dock", systemImage: edge == .left ? "sidebar.left" : "sidebar.right")
                .font(.headline)
        }
    }

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Items").font(.subheadline.weight(.semibold))
                Spacer()
                Button("Add…") {
                    let urls = ItemPicker.choose()
                    if !urls.isEmpty { state.drop(urls, on: edge, at: nil) }
                }
            }
            List {
                ForEach(side.items) { item in
                    ItemRow(item: item)
                        .contextMenu { rowMenu(for: item) }
                }
                .onMove { source, destination in
                    guard let index = source.first else { return }
                    let id = side.items[index].id
                    state.update { $0.moving(itemID: id, to: edge, at: destination) }
                }
            }
            .frame(minHeight: 200)
            .dropDestination(for: DockDragPayload.self) { payloads, _ in
                state.drop(payloads.map(\.url), on: edge, at: nil)
                return true
            }
        }
    }

    private var shelvesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shelves").font(.subheadline.weight(.semibold))
            ForEach(side.shelves) { shelf in
                HStack {
                    Image(systemName: "tray.full")
                    VStack(alignment: .leading, spacing: 0) {
                        Text(shelf.name)
                        Text((shelf.folderPath as NSString).abbreviatingWithTildeInPath).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Button {
                        state.removeShelf(shelf, from: edge)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove from dock (the folder and its files are kept)")
                }
            }
            HStack {
                TextField("New shelf name", text: $newShelfName)
                    .onSubmit(addNamedShelf)
                Button("Add", action: addNamedShelf)
                    .disabled(newShelfName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("Use Folder…") {
                    guard let folder = ItemPicker.chooseFolder() else { return }
                    state.addShelf(Shelf(name: folder.lastPathComponent, folderPath: folder.path), to: edge)
                }
            }
            Text("New shelves are folders in ~/Shelf. Files dropped on a shelf are moved there.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func rowMenu(for item: DockItem) -> some View {
        // Copies rather than moves: the bottom Dock only changes after "Apply", so removing
        // the item here first could lose it if the draft is never applied.
        Button("Add to Bottom Dock") { nativeDock.add([item.url]) }
        ItemMenu(item: item, edge: edge)
    }

    private func addNamedShelf() {
        let name = newShelfName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        state.addShelf(Shelf.named(name), to: edge)
        newShelfName = ""
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<SideDockConfig, Value>) -> Binding<Value> {
        Binding(
            get: { side[keyPath: keyPath] },
            set: { value in state.updateSide(edge) { $0[keyPath: keyPath] = value } }
        )
    }
}
