import Foundation

/// The pinned contents of the native macOS Dock, as stored in the `com.apple.dock` preferences.
///
/// `apps` maps to `persistent-apps` (left of the divider), `others` to `persistent-others`
/// (folders and files, right of the divider).
public struct NativeDockLayout: Hashable, Sendable {
    public var apps: [DockItem]
    public var others: [DockItem]

    public init(apps: [DockItem] = [], others: [DockItem] = []) {
        self.apps = apps
        self.others = others
    }

    /// Appends items to the section the Dock would put them in, skipping paths already pinned.
    public func adding(_ items: [DockItem]) -> NativeDockLayout {
        var copy = self
        for item in items where !copy.contains(path: item.path) {
            if item.kind == .app {
                copy.apps.append(item)
            } else {
                copy.others.append(item)
            }
        }
        return copy
    }

    public enum Section: Hashable, Sendable {
        case apps
        case others

        /// The Dock keeps apps left of its divider and folders/files right of it.
        public static func of(_ item: DockItem) -> Section { item.kind == .app ? .apps : .others }
    }

    /// Places dropped items, moving anything already pinned instead of duplicating it. Items that
    /// belong in `section` go to `index` (counted before removals, like SwiftUI drops); the rest
    /// are appended to the section the Dock requires for them.
    public func placing(_ items: [DockItem], in section: Section, at index: Int?) -> NativeDockLayout {
        let existing = Dictionary((apps + others).map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        let resolved = items.map { existing[$0.path] ?? $0 }
        var copy = self
        // A pinned item keeps its kind, so it always stays within its own section.
        for target in [Section.apps, .others] {
            let incoming = resolved.filter { Section.of($0) == target }
            guard !incoming.isEmpty else { continue }
            copy[target] = copy[target].placing(incoming, at: target == section ? index : nil)
        }
        return copy
    }

    public subscript(section: Section) -> [DockItem] {
        get {
            switch section {
            case .apps: apps
            case .others: others
            }
        }
        set {
            switch section {
            case .apps: apps = newValue
            case .others: others = newValue
            }
        }
    }

    public func removing(paths: Set<String>) -> NativeDockLayout {
        NativeDockLayout(apps: apps.filter { !paths.contains($0.path) }, others: others.filter { !paths.contains($0.path) })
    }

    public var isEmpty: Bool { apps.isEmpty && others.isEmpty }

    func contains(path: String) -> Bool {
        (apps + others).contains { $0.path == path }
    }
}

/// Converts between `NativeDockLayout` and the raw tile dictionaries the Dock reads.
public enum NativeDockPlist {
    public typealias Tile = [String: Any]

    public static let appsKey = "persistent-apps"
    public static let othersKey = "persistent-others"

    public static func items(from tiles: [Tile]) -> [DockItem] {
        tiles.compactMap(item(from:))
    }

    static func item(from tile: Tile) -> DockItem? {
        guard let tileData = tile["tile-data"] as? [String: Any],
              let fileData = tileData["file-data"] as? [String: Any],
              let urlString = fileData["_CFURLString"] as? String
        else { return nil }

        let url = URL(string: urlString).flatMap { $0.isFileURL ? $0 : nil }
            ?? URL(fileURLWithPath: urlString)
        let path = url.standardizedFileURL.path
        let kind: DockItem.Kind
        switch tile["tile-type"] as? String {
        case "directory-tile": kind = .folder
        default: kind = url.pathExtension.lowercased() == "app" ? .app : .file
        }
        return DockItem(kind: kind, path: path)
    }

    /// Builds tiles for `items`, reusing the original tile for any path that already existed so
    /// the Dock keeps its own metadata (GUIDs, folder view settings) for unchanged entries.
    /// Tiles this app cannot represent (spacers, URL tiles, …) are kept at their original
    /// positions so applying a layout never silently deletes them.
    public static func tiles(for items: [DockItem], reusing existing: [Tile]) -> [Tile] {
        var byPath: [String: Tile] = [:]
        var opaque: [(index: Int, tile: Tile)] = []
        for (index, tile) in existing.enumerated() {
            if let item = item(from: tile) {
                byPath[item.path] = byPath[item.path] ?? tile
            } else {
                opaque.append((index, tile))
            }
        }
        var result = items.map { byPath[$0.path] ?? newTile(for: $0) }
        for (index, tile) in opaque {
            result.insert(tile, at: index.clamped(to: 0...result.count))
        }
        return result
    }

    static func newTile(for item: DockItem) -> Tile {
        let url = URL(fileURLWithPath: item.path, isDirectory: item.kind != .file)
        var tileData: [String: Any] = [
            "file-data": [
                "_CFURLString": url.absoluteString,
                "_CFURLStringType": 15
            ],
            "file-label": item.displayName
        ]
        if item.kind == .app, let bundleID = Bundle(path: item.path)?.bundleIdentifier {
            tileData["bundle-identifier"] = bundleID
        }
        if item.kind == .folder {
            // Grid view, sorted by name, shown as a folder icon.
            tileData["arrangement"] = 1
            tileData["displayas"] = 1
            tileData["showas"] = 2
        }
        return [
            "tile-data": tileData,
            "tile-type": item.kind == .folder ? "directory-tile" : "file-tile"
        ]
    }
}
