import CoreTransferable
import DockyCore
import UniformTypeIdentifiers

extension UTType {
    /// Declared in the app's Info.plist (see scripts/build-app.sh).
    static let dockyItem = UTType(exportedAs: "net.personal.docky.item")
}

/// What is dragged between docks. It deliberately does not export a file URL, so dropping a
/// dock icon onto Finder or a shelf never moves the underlying app. Finder drops are imported.
struct DockDragPayload: Codable, Transferable {
    let path: String
    /// The dock the drag started in, so a drop can take the item out of it; nil for Finder.
    let source: DockID?

    init(path: String, source: DockID?) {
        self.path = URL(fileURLWithPath: path).standardizedFileURL.path
        self.source = source
    }

    init(_ item: DockItem, from source: DockID) {
        self.init(path: item.path, source: source)
    }

    var url: URL { URL(fileURLWithPath: path) }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .dockyItem)
        ProxyRepresentation(importing: { (url: URL) in
            guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
            return DockDragPayload(path: url.path, source: nil)
        })
    }
}
