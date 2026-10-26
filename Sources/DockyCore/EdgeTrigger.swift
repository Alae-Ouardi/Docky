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

    /// Where along the edge the pointer can reveal the dock: the dock's own extent, widened to at
    /// least `minimumRevealFraction` of the edge so a small dock is still easy to hit.
    public static let minimumRevealFraction: CGFloat = 1.0 / 3.0

    public func revealSpan(dock: CGRect, screen: CGRect) -> ClosedRange<CGFloat> {
        let (low, high, edgeLow, edgeHigh) = edge.isHorizontal
            ? (dock.minX, dock.maxX, screen.minX, screen.maxX)
            : (dock.minY, dock.maxY, screen.minY, screen.maxY)
        let minimum = (edgeHigh - edgeLow) * Self.minimumRevealFraction
        guard high - low < minimum else { return low...high }
        let centre = (low + high) / 2
        let start = min(max(centre - minimum / 2, edgeLow), edgeHigh - minimum)
        return start...(start + minimum)
    }

    /// While revealed, the dock stays open when the pointer is over it (plus `slack`), between it
    /// and its screen edge (the menu bar, for the top dock), or resting on the edge row anywhere
    /// in the reveal span — where a pointer pushed against the edge stops.
    public func keepsOpen(pointer: CGPoint, dock: CGRect, screen: CGRect, slack: CGFloat) -> Bool {
        let towardEdge = dock.union(edgeStrip(along: dock.minX...dock.maxX, dock.minY...dock.maxY, screen: screen))
        return towardEdge.insetBy(dx: -slack, dy: -slack).contains(pointer)
            || isInZone(pointer, screen: screen, dockSpan: revealSpan(dock: dock, screen: screen))
    }

    /// A thin strip on the screen edge covering `xs` (top edge) or `ys` (side edges).
    private func edgeStrip(along xs: ClosedRange<CGFloat>, _ ys: ClosedRange<CGFloat>, screen: CGRect) -> CGRect {
        let width = Self.edgeWidth
        switch edge {
        case .left: return CGRect(x: screen.minX, y: ys.lowerBound, width: width, height: ys.upperBound - ys.lowerBound)
        case .right: return CGRect(x: screen.maxX - width, y: ys.lowerBound, width: width, height: ys.upperBound - ys.lowerBound)
        case .top: return CGRect(x: xs.lowerBound, y: screen.maxY - width, width: xs.upperBound - xs.lowerBound, height: width)
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
