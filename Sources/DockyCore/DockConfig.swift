import Foundation

/// A screen edge that can host a custom dock. The bottom edge belongs to the native Dock.
public enum DockEdge: String, Codable, CaseIterable, Sendable {
    case left
    case right

    public var opposite: DockEdge { self == .left ? .right : .left }
    public var title: String { self == .left ? "Left" : "Right" }
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
    public var right: SideDockConfig

    public init(left: SideDockConfig = SideDockConfig(), right: SideDockConfig = SideDockConfig()) {
        self.left = left
        self.right = right
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            left: try container.decodeIfPresent(SideDockConfig.self, forKey: .left) ?? SideDockConfig(),
            right: try container.decodeIfPresent(SideDockConfig.self, forKey: .right) ?? SideDockConfig()
        )
    }

    public subscript(edge: DockEdge) -> SideDockConfig {
        get { edge == .left ? left : right }
        set {
            switch edge {
            case .left: left = newValue
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

    /// Handles files dropped on a dock: paths already pinned are moved (preferring the copy on
    /// the destination edge), unknown paths are added. A nil index appends.
    func dropping(_ urls: [URL], on edge: DockEdge, at index: Int?) -> DockConfig {
        var result = self
        var insertAt = index
        for url in urls {
            let path = url.standardizedFileURL.path
            let target = insertAt ?? result[edge].items.count
            if let existing = result.item(at: path, preferring: edge) {
                result = result.moving(itemID: existing.id, to: edge, at: target)
            } else {
                result = result.adding([DockItem(url: url)], to: edge, at: target)
            }
            if insertAt != nil {
                insertAt = (result[edge].items.firstIndex { $0.path == path } ?? target) + 1
            }
        }
        return result
    }

    private func item(at path: String, preferring edge: DockEdge) -> DockItem? {
        let order = [edge] + DockEdge.allCases.filter { $0 != edge }
        return order.lazy.compactMap { e in self[e].items.first { $0.path == path } }.first
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
