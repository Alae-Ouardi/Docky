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

    func layout() {
        panel.setFrame(shownFrame, display: true)
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
        let width = DockMetrics.width(iconSize: side.iconSize)
        let height = min(DockMetrics.contentHeight(for: side), visible.height - 2 * DockMetrics.screenMargin)
        let x = edge == .left ? visible.minX : visible.maxX - width
        return NSRect(x: x, y: visible.midY - height / 2, width: width, height: height)
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

        if isRevealed {
            let keepOpen = state.openShelfID != nil
                || shown.insetBy(dx: -Self.hideSlack, dy: -Self.hideSlack).contains(mouse)
            if keepOpen {
                lastInsideAt = Date()
            } else if Date().timeIntervalSince(lastInsideAt) > Self.hideDelay {
                setRevealed(false, animated: true)
            }
        } else {
            let hasNeighbour = edgeTrigger.hasNeighbour(of: screenFrame, among: NSScreen.screens.map(\.frame))
            if edgeTrigger.shouldReveal(pointer: mouse, screen: screenFrame, dockSpan: shown.minY...shown.maxY,
                                        hasNeighbourScreen: hasNeighbour) {
                setRevealed(true, animated: true)
            }
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
