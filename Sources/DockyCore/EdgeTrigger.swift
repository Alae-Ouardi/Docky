import CoreGraphics
import Foundation

/// Decides when the pointer should reveal an auto-hidden dock.
///
/// The pointer must be on the dock's own screen, within `edgeWidth` of its edge and level with
/// the dock. When the pointer has another reason to be at that edge — a neighbouring display to
/// cross into, or the menu bar along the top — it also has to rest there for `restDwell`, so
/// passing through or reaching for a menu does not flash the dock.
public struct EdgeTrigger: Sendable {
    public static let edgeWidth: CGFloat = 2
    public static let restDwell: TimeInterval = 0.25

    public let edge: DockEdge
    private var enteredAt: Date?

    public init(edge: DockEdge) {
        self.edge = edge
    }

    /// Feeds one pointer sample; returns true when the dock should be revealed.
    /// `dockSpan` is the dock's extent along the edge (y for side docks, x for the top dock).
    public mutating func shouldReveal(
        pointer: CGPoint,
        screen: CGRect,
        dockSpan: ClosedRange<CGFloat>,
        hasNeighbourScreen: Bool,
        now: Date = Date()
    ) -> Bool {
        guard isInZone(pointer, screen: screen, dockSpan: dockSpan) else {
            enteredAt = nil
            return false
        }
        guard hasNeighbourScreen || edge == .top else { return true }
        let start = enteredAt ?? now
        enteredAt = start
        return now.timeIntervalSince(start) >= Self.restDwell
    }

    public mutating func reset() {
        enteredAt = nil
    }

    func isInZone(_ pointer: CGPoint, screen: CGRect, dockSpan: ClosedRange<CGFloat>) -> Bool {
        // Pointer x runs from minX up to (but not including) maxX on a screen.
        guard pointer.x >= screen.minX, pointer.x < screen.maxX,
              pointer.y >= screen.minY, pointer.y <= screen.maxY
        else { return false }
        switch edge {
        case .left: return dockSpan.contains(pointer.y) && pointer.x < screen.minX + Self.edgeWidth
        case .right: return dockSpan.contains(pointer.y) && pointer.x >= screen.maxX - Self.edgeWidth
        case .top: return dockSpan.contains(pointer.x) && pointer.y >= screen.maxY - Self.edgeWidth
        }
    }

    /// Whether any other screen touches `screen` on the dock's edge.
    public func hasNeighbour(of screen: CGRect, among screens: [CGRect]) -> Bool {
        screens.contains { other in
            guard other != screen else { return false }
            let overlapsVertically = other.maxY > screen.minY && other.minY < screen.maxY
            let overlapsHorizontally = other.maxX > screen.minX && other.minX < screen.maxX
            switch edge {
            case .left: return overlapsVertically && abs(other.maxX - screen.minX) < 1
            case .right: return overlapsVertically && abs(other.minX - screen.maxX) < 1
            case .top: return overlapsHorizontally && abs(other.minY - screen.maxY) < 1
            }
        }
    }
}
