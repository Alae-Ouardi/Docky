import AppKit
import DockyCore
import SwiftUI

/// Places one side dock on its screen edge and handles the auto-hide behaviour.
@MainActor
final class DockWindowController {
    private static let hideDelay: TimeInterval = 0.5
    private static let hideSlack: CGFloat = 8
    private static let pollInterval: TimeInterval = 0.1

    let edge: DockEdge
    private let state: AppState
    private let panel: DockPanel
    private var visibility: DockVisibility?
    private var isRevealed = true
    private var lastInsideAt = Date()
    private var hoverTimer: Timer?
    private var edgeTrigger: EdgeTrigger
    /// Whether another display continues past this dock's edge; refreshed in `layout()`.
    private var hasNeighbourScreen = false

    init(edge: DockEdge, state: AppState) {
        self.edge = edge
        self.edgeTrigger = EdgeTrigger(edge: edge)
        self.state = state
        self.panel = DockPanel(rootView: DockView(edge: edge).environment(state))
    }

    private var side: SideDockConfig { state.config[edge] }

    func apply(_ side: SideDockConfig) {
        if side.visibility != visibility {
            visibility = side.visibility
            setRevealed(side.visibility == .alwaysVisible, animated: false)
            configureAutoHide()
        }
        layout()
        panel.orderFrontRegardless()
    }

    /// Called on every config change and whenever displays are added, moved or resized.
    func layout() {
        panel.setFrame(shownFrame, display: true)
        if let frame = screen?.frame {
            hasNeighbourScreen = edgeTrigger.hasNeighbour(of: frame, among: NSScreen.screens.map(\.frame))
        }
    }

    func close() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        state.openShelfID = nil
        panel.orderOut(nil)
    }

    // MARK: - Geometry

    /// Docks live on the primary display (the one with the menu bar).
    private var screen: NSScreen? { NSScreen.screens.first }

    private var shownFrame: NSRect {
        guard let visible = screen?.visibleFrame else { return .zero }
        let thickness = DockMetrics.thickness(iconSize: side.iconSize)
        let margin = 2 * DockMetrics.screenMargin
        switch edge {
        case .left, .right:
            let height = min(DockMetrics.length(for: side), visible.height - margin)
            let x = edge == .left ? visible.minX : visible.maxX - thickness
            return NSRect(x: x, y: visible.midY - height / 2, width: thickness, height: height)
        case .top:
            // Just below the menu bar, centred horizontally.
            let width = min(DockMetrics.length(for: side), visible.width - margin)
            return NSRect(x: visible.midX - width / 2, y: visible.maxY - thickness, width: width, height: thickness)
        }
    }

    // MARK: - Auto-hide

    private func configureAutoHide() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        guard side.visibility == .autoHide else { return }

        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = Self.pollInterval / 2
        // Default mode only: the timer pauses while a context menu or drag is tracking,
        // so the dock does not fade away underneath an open menu.
        RunLoop.main.add(timer, forMode: .default)
        hoverTimer = timer
    }

    private func tick() {
        guard let screenFrame = screen?.frame else { return }
        let mouse = NSEvent.mouseLocation
        let shown = shownFrame
        let now = Date()

        if isRevealed {
            let keepOpen = state.openShelfID != nil
                || edgeTrigger.keepsOpen(pointer: mouse, dock: shown, screen: screenFrame, slack: Self.hideSlack)
            if keepOpen {
                lastInsideAt = now
            } else if now.timeIntervalSince(lastInsideAt) > Self.hideDelay {
                setRevealed(false, animated: true)
            }
        } else if edgeTrigger.shouldReveal(pointer: mouse, screen: screenFrame,
                                           dockSpan: edgeTrigger.revealSpan(dock: shown, screen: screenFrame),
                                           hasNeighbourScreen: hasNeighbourScreen, now: now) {
            setRevealed(true, animated: true)
        }
    }

    /// Hidden docks stay in place but are invisible and click-through, so they never end up
    /// on a neighbouring display the way an off-screen frame would.
    private func setRevealed(_ revealed: Bool, animated: Bool) {
        isRevealed = revealed
        edgeTrigger.reset()
        lastInsideAt = Date()
        panel.ignoresMouseEvents = !revealed
        let alpha: CGFloat = revealed ? 1 : 0
        guard animated else {
            panel.alphaValue = alpha
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = alpha
        }
    }
}
