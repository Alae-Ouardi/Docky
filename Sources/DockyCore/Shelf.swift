import Foundation

/// A named drop zone on a side dock, backed by a real folder on disk.
public struct Shelf: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let folderPath: String

    public init(id: UUID = UUID(), name: String, folderPath: String) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
    }

    public var folderURL: URL { URL(fileURLWithPath: folderPath, isDirectory: true) }

    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Shelf", isDirectory: true)
    }

    /// A shelf whose folder lives under `~/Shelf/<name>`.
    public static func named(_ name: String, root: URL = Shelf.defaultRoot) -> Shelf {
        let safeName = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            // No leading dots: "." and ".." would point outside ~/Shelf, others would be hidden.
            .drop { $0 == "." }
        let finalName = safeName.isEmpty ? "Shelf" : String(safeName)
        return Shelf(name: finalName, folderPath: root.appendingPathComponent(finalName, isDirectory: true).path)
    }
}

public enum ShelfError: Error, Equatable, LocalizedError {
    case folderUnavailable(String)
    /// Some files were not moved; each entry is "name: reason". The others were moved.
    case notMoved([String])

    public var errorDescription: String? {
        switch self {
        case .folderUnavailable(let path): "The shelf folder \(path) could not be created."
        case .notMoved(let files): "Some items were not moved to the shelf — \(files.joined(separator: "; "))"
        }
    }
}

/// Moves files into shelf folders and lists what a shelf holds.
public struct ShelfFileManager: Sendable {
    public init() {}

    /// Moves each file into the shelf folder, renaming on conflict ("photo 2.jpg").
    /// Files already inside the folder are left alone; unsafe items are refused. Every file is
    /// attempted, then `.notMoved` lists any that were skipped or failed.
    public func move(_ urls: [URL], into shelf: Shelf) throws(ShelfError) {
        let folder = shelf.folderURL.resolvingSymlinksInPath().standardizedFileURL
        try ensureFolder(folder)
        var notMoved: [String] = []
        for url in urls.map({ $0.resolvingSymlinksInPath().standardizedFileURL }) {
            if url.deletingLastPathComponent().path == folder.path { continue }
            if let reason = Self.refusal(for: url, shelfFolder: folder) {
                notMoved.append("\(url.lastPathComponent): \(reason)")
                continue
            }
            do {
                try FileManager.default.moveItem(at: url, to: uniqueDestination(for: url.lastPathComponent, in: folder))
            } catch {
                notMoved.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        if !notMoved.isEmpty { throw .notMoved(notMoved) }
    }

    /// Why an item must not be moved onto a shelf, or nil when it is safe.
    static func refusal(for url: URL, shelfFolder: URL) -> String? {
        let path = url.path
        if url.pathExtension.lowercased() == "app" { return "apps stay where they are installed" }
        if shelfFolder.path == path || shelfFolder.path.hasPrefix(path + "/") {
            return "it contains the shelf itself"
        }
        let protectedRoots = ["/Applications", "/System", "/Library", "/usr", "/bin", "/sbin"]
        if protectedRoots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return "system locations are protected"
        }
        let values = try? url.resourceValues(forKeys: [.isVolumeKey, .isDirectoryKey])
        if path == "/" || values?.isVolume == true { return "whole volumes cannot be moved" }
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        if path == home || (url.deletingLastPathComponent().path == home && values?.isDirectory == true) {
            return "top-level home folders are protected"
        }
        return nil
    }

    /// Visible files in the shelf, newest first.
    public func contents(of shelf: Shelf) -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .addedToDirectoryDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: shelf.folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .map { ($0, Self.sortDate(of: $0)) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    public func ensureFolder(_ folder: URL) throws(ShelfError) {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw .folderUnavailable(folder.path)
        }
    }

    func uniqueDestination(for fileName: String, in folder: URL) -> URL {
        let candidate = folder.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }

        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var counter = 2
        while true {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            let next = folder.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: next.path) { return next }
            counter += 1
        }
    }

    private static func sortDate(of url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.addedToDirectoryDateKey, .contentModificationDateKey])
        return values?.addedToDirectoryDate ?? values?.contentModificationDate ?? .distantPast
    }
}
