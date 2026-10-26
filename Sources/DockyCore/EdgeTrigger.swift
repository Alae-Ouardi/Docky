import CoreGraphics
import Foundation

/// Decides when the pointer should reveal an auto-hidden side dock.
///
/// The pointer must be on the dock's own screen, within `edgeWidth` of its edge and level with
/// the dock. When another display continues past that edge, the pointer also has to rest there
/// for `crossingDwell`, so moving between monitors does not flash the dock.
public struct EdgeTrigger: Sendable {
    public static let edgeWidth: CGFloat = 2
    public static let crossingDwell: TimeInterval = 0.25

    public let edge: DockEdge
    private var enteredAt: Date?

    public init(edge: DockEdge) {
        self.edge = edge
    }

    /// Feeds one pointer sample; returns true when the dock should be revealed.
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
        guard hasNeighbourScreen else { return true }
        let start = enteredAt ?? now
        enteredAt = start
        return now.timeIntervalSince(start) >= Self.crossingDwell
    }

    public mutating func reset() {
        enteredAt = nil
    }

    func isInZone(_ pointer: CGPoint, screen: CGRect, dockSpan: ClosedRange<CGFloat>) -> Bool {
        // Pointer coordinates run from minX up to (but not including) maxX on a screen.
        guard pointer.x >= screen.minX, pointer.x < screen.maxX,
              pointer.y >= screen.minY, pointer.y <= screen.maxY,
              dockSpan.contains(pointer.y)
        else { return false }
        switch edge {
        case .left: return pointer.x < screen.minX + Self.edgeWidth
        case .right: return pointer.x >= screen.maxX - Self.edgeWidth
        }
    }

    /// Whether any other screen touches `screen` on the dock's edge.
    public func hasNeighbour(of screen: CGRect, among screens: [CGRect]) -> Bool {
        screens.contains { other in
            guard other != screen,
                  other.maxY > screen.minY, other.minY < screen.maxY
            else { return false }
            switch edge {
            case .left: return abs(other.maxX - screen.minX) < 1
            case .right: return abs(other.minX - screen.maxX) < 1
            }
        }
    }
}
