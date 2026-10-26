import Foundation

/// Something that can be pinned to a dock: an application, a folder or a plain file.
public struct DockItem: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case app
        case folder
        case file
    }

    public let id: UUID
    public let kind: Kind
    public let path: String

    public init(id: UUID = UUID(), kind: Kind, path: String) {
        self.id = id
        self.kind = kind
        self.path = path
    }

    /// Builds an item from a file URL, inferring its kind from the file system.
    public init(url: URL) {
        let standardized = url.standardizedFileURL
        self.init(kind: Self.kind(of: standardized), path: standardized.path)
    }

    public var url: URL { URL(fileURLWithPath: path) }

    /// False when the pinned file was moved or deleted; views dim such items.
    public var exists: Bool { FileManager.default.fileExists(atPath: path) }

    public var displayName: String {
        let name = url.lastPathComponent
        return kind == .app ? url.deletingPathExtension().lastPathComponent : name
    }

    public static func kind(of url: URL) -> Kind {
        if url.pathExtension.lowercased() == "app" { return .app }
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue ? .folder : .file
    }
}
