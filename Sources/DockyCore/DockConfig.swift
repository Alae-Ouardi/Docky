import Foundation

/// A screen edge that can host a custom dock. The bottom edge belongs to the native Dock.
public enum DockEdge: String, Codable, CaseIterable, Sendable {
    case left
    case top
    case right

    public var title: String {
        switch self {
        case .left: "Left"
        case .top: "Top"
        case .right: "Right"
        }
    }

    /// Top docks lay their icons out in a row; side docks in a column.
    public var isHorizontal: Bool { self == .top }
}

public enum DockVisibility: String, Codable, CaseIterable, Sendable {
    case alwaysVisible
    case autoHide
}

public struct SideDockConfig: Codable, Hashable, Sendable {
    public static let iconSizeRange: ClosedRange<Double> = 24...96
    public static let defaultIconSize: Double = 48

    public var isEnabled: Bool
    public var visibility: DockVisibility
    public var iconSize: Double
    public var items: [DockItem]
    public var shelves: [Shelf]

    public init(
        isEnabled: Bool = false,
        visibility: DockVisibility = .alwaysVisible,
        iconSize: Double = SideDockConfig.defaultIconSize,
        items: [DockItem] = [],
        shelves: [Shelf] = []
    ) {
        self.isEnabled = isEnabled
        self.visibility = visibility
        self.iconSize = iconSize.clamped(to: Self.iconSizeRange)
        self.items = items
        self.shelves = shelves
    }

    // Tolerates missing keys so configs written by older versions still load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false,
            visibility: try container.decodeIfPresent(DockVisibility.self, forKey: .visibility) ?? .alwaysVisible,
            iconSize: try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? Self.defaultIconSize,
            items: try container.decodeIfPresent([DockItem].self, forKey: .items) ?? [],
            shelves: try container.decodeIfPresent([Shelf].self, forKey: .shelves) ?? []
        )
    }
}

public struct DockConfig: Codable, Hashable, Sendable {
    public var left: SideDockConfig
    public var top: SideDockConfig
    public var right: SideDockConfig

    public init(
        left: SideDockConfig = SideDockConfig(),
        top: SideDockConfig = SideDockConfig(),
        right: SideDockConfig = SideDockConfig()
    ) {
        self.left = left
        self.top = top
        self.right = right
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            left: try container.decodeIfPresent(SideDockConfig.self, forKey: .left) ?? SideDockConfig(),
            top: try container.decodeIfPresent(SideDockConfig.self, forKey: .top) ?? SideDockConfig(),
            right: try container.decodeIfPresent(SideDockConfig.self, forKey: .right) ?? SideDockConfig()
        )
    }

    public subscript(edge: DockEdge) -> SideDockConfig {
        get {
            switch edge {
            case .left: left
            case .top: top
            case .right: right
            }
        }
        set {
            switch edge {
            case .left: left = newValue
            case .top: top = newValue
            case .right: right = newValue
            }
        }
    }
}

// MARK: - Item editing (each returns a new config, the original is untouched)

public extension DockConfig {
    func adding(_ newItems: [DockItem], to edge: DockEdge, at index: Int? = nil) -> DockConfig {
        var copy = self
        let existing = copy[edge].items
        let fresh = newItems.filter { item in !existing.contains { $0.path == item.path } }
        let insertAt = (index ?? existing.count).clamped(to: 0...existing.count)
        copy[edge].items.insert(contentsOf: fresh, at: insertAt)
        return copy
    }

    func removing(itemID: UUID) -> DockConfig {
        var copy = self
        for edge in DockEdge.allCases {
            copy[edge].items.removeAll { $0.id == itemID }
        }
        return copy
    }

    func removing(paths: Set<String>, from edge: DockEdge) -> DockConfig {
        var copy = self
        copy[edge].items.removeAll { paths.contains($0.path) }
        return copy
    }

    /// Moves an item to `edge` at `index`, which is interpreted in the destination list
    /// as it looks *before* the item is removed from its source.
    func moving(itemID: UUID, to edge: DockEdge, at index: Int) -> DockConfig {
        guard let source = self.edge(containing: itemID),
              let sourceIndex = self[source].items.firstIndex(where: { $0.id == itemID })
        else { return self }

        var copy = self
        let item = copy[source].items.remove(at: sourceIndex)
        let target = (source == edge && sourceIndex < index ? index - 1 : index)
            .clamped(to: 0...copy[edge].items.count)
        copy[edge].items.insert(item, at: target)
        return copy
    }

    func edge(containing itemID: UUID) -> DockEdge? {
        DockEdge.allCases.first { edge in self[edge].items.contains { $0.id == itemID } }
    }

    /// Places dropped files on one dock: paths already on that dock are reordered, others are
    /// added. Other docks are untouched; moving between docks removes from the source first.
    /// A nil index appends.
    func dropping(_ urls: [URL], on edge: DockEdge, at index: Int?) -> DockConfig {
        var copy = self
        copy[edge].items = copy[edge].items.placing(urls.map(DockItem.init(url:)), at: index)
        return copy
    }
}

/// Identifies any dock Docky manages: one of its own, or the macOS bottom Dock.
public enum DockID: Codable, Hashable, Sendable {
    case custom(DockEdge)
    case bottom
}

extension Array where Element == DockItem {
    /// Inserts `items` at `index` (counted before removals, like SwiftUI drop indices), moving
    /// any that are already in the list instead of duplicating them. Existing entries keep
    /// their identity. A nil index appends.
    func placing(_ items: [DockItem], at index: Int?) -> [DockItem] {
        let paths = Set(items.map(\.path))
        let existing = Dictionary(filter { paths.contains($0.path) }.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
        let removedBefore = index.map { position in prefix(position).filter { paths.contains($0.path) }.count } ?? 0
        var result = filter { !paths.contains($0.path) }
        var seen = Set<String>()
        let placed = items.filter { seen.insert($0.path).inserted }.map { existing[$0.path] ?? $0 }
        let position = index.map { ($0 - removedBefore).clamped(to: 0...result.count) } ?? result.count
        result.insert(contentsOf: placed, at: position)
        return result
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
