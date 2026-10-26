import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    /// Declared in the app's Info.plist (see scripts/build-app.sh).
    static let customDockItem = UTType(exportedAs: "net.personal.docky.item")
}

/// What is dragged between docks. It deliberately does not export a file URL, so dropping a
/// dock icon onto Finder or a shelf never moves the underlying app. Finder drops are imported.
struct DockDragPayload: Codable, Transferable {
    let path: String

    var url: URL { URL(fileURLWithPath: path) }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .customDockItem)
        ProxyRepresentation(importing: { (url: URL) in
            guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
            return DockDragPayload(path: url.path)
        })
    }
}
