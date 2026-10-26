import DockyCore
import QuickLook
import SwiftUI

/// Grid of the files on a shelf, with thumbnails, drag-out, Quick Look and file actions.
struct ShelfContentView: View {
    let shelf: Shelf

    @Environment(AppState.self) private var state
    @State private var files: [URL] = []
    @State private var selection: URL?
    @State private var previewURL: URL?
    @State private var isTargeted = false
    @FocusState private var isFocused: Bool

    private static let tileSize: CGFloat = 76
    private let columns = Array(repeating: GridItem(.fixed(tileSize + 8), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            dropArea
        }
        .padding(14)
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear { isFocused = true }
        .onKeyPress(.space) {
            guard let selection else { return .ignored }
            previewURL = selection
            return .handled
        }
        .quickLookPreview($previewURL, in: files)
        .task(id: state.shelfRevision) { files = state.shelfContents(shelf) }
    }

    private var dropArea: some View {
        Group {
            if files.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .frame(width: 4 * (Self.tileSize + 16), height: 300)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                .opacity(isTargeted ? 1 : 0)
        )
        .dropDestination(for: URL.self) { urls, _ in
            state.moveFiles(urls.filter(\.isFileURL), to: shelf)
            return true
        } isTargeted: { isTargeted = $0 }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(files, id: \.self) { url in
                    fileTile(url)
                }
            }
            .padding(4)
        }
    }

    private func fileTile(_ url: URL) -> some View {
        ShelfFileTile(url: url, size: Self.tileSize, isSelected: selection == url)
            .onTapGesture(count: 2) { ItemActions.open(url) }
            .onTapGesture { selection = url }
            .draggable(url)
            .contextMenu { menu(for: url) }
    }

    private var header: some View {
        HStack {
            Label(shelf.name, systemImage: "tray.full")
                .font(.headline)
            Spacer()
            Text("\(files.count) item\(files.count == 1 ? "" : "s")")
                .foregroundStyle(.secondary)
            Button {
                ItemActions.open(shelf.folderURL)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Open shelf folder in Finder")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Shelf is empty",
            systemImage: "tray",
            description: Text("Drop files here or on the shelf icon to move them into \(shelf.folderURL.lastPathComponent).")
        )
    }

    @ViewBuilder
    private func menu(for url: URL) -> some View {
        Button("Open") { ItemActions.open(url) }
        Button("Quick Look") { previewURL = url }
        Button("Show in Finder") { ItemActions.revealInFinder(url) }
        Divider()
        Button("Move to Trash", role: .destructive) { state.trash(url) }
    }
}

/// A single file on a shelf: Quick Look thumbnail plus its name.
private struct ShelfFileTile: View {
    let url: URL
    let size: CGFloat
    let isSelected: Bool

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: size, height: size)
            Text(url.lastPathComponent)
                .font(.caption)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(width: size + 8)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : .clear)
        )
        .contentShape(Rectangle())
        .help(url.lastPathComponent)
        .task(id: url) { image = await ItemActions.thumbnail(for: url, size: size) }
    }
}
