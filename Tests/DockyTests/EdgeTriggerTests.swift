import CoreGraphics
import Foundation
import Testing
@testable import DockyCore

struct EdgeTriggerTests {
    let primary = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let external = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
    let span: ClosedRange<CGFloat> = 200...800
    let start = Date(timeIntervalSince1970: 1000)

    @Test func revealsAtEdgeWithoutNeighbour() {
        var trigger = EdgeTrigger(edge: .right)
        let r1 = trigger.shouldReveal(pointer: CGPoint(x: 1511, y: 500), screen: primary, dockSpan: span,
                                     hasNeighbourScreen: false, now: start)
        #expect(r1)
    }

    @Test func pointerOnOtherMonitorNeverReveals() {
        // The flicker bug: anywhere past maxX used to count as "at the edge".
        var trigger = EdgeTrigger(edge: .right)
        for offset in stride(from: 0.0, through: 2.0, by: 0.1) {
            let revealed = trigger.shouldReveal(pointer: CGPoint(x: 2000, y: 500), screen: primary, dockSpan: span,
                                                hasNeighbourScreen: true, now: start.addingTimeInterval(offset))
            #expect(!revealed)
        }
    }

    @Test func crossingToNeighbourRequiresDwell() {
        var trigger = EdgeTrigger(edge: .right)
        let edgePoint = CGPoint(x: 1511.5, y: 500)
        let r2 = trigger.shouldReveal(pointer: edgePoint, screen: primary, dockSpan: span,
                                      hasNeighbourScreen: true, now: start)
        #expect(!r2)
        let r3 = trigger.shouldReveal(pointer: edgePoint, screen: primary, dockSpan: span,
                                      hasNeighbourScreen: true, now: start.addingTimeInterval(0.1))
        #expect(!r3)
        let r4 = trigger.shouldReveal(pointer: edgePoint, screen: primary, dockSpan: span,
                                     hasNeighbourScreen: true, now: start.addingTimeInterval(0.3))
        #expect(r4)
    }

    @Test func leavingEdgeResetsDwell() {
        var trigger = EdgeTrigger(edge: .right)
        _ = trigger.shouldReveal(pointer: CGPoint(x: 1511, y: 500), screen: primary, dockSpan: span,
                                 hasNeighbourScreen: true, now: start)
        _ = trigger.shouldReveal(pointer: CGPoint(x: 1300, y: 500), screen: primary, dockSpan: span,
                                 hasNeighbourScreen: true, now: start.addingTimeInterval(0.2))
        let r5 = trigger.shouldReveal(pointer: CGPoint(x: 1511, y: 500), screen: primary, dockSpan: span,
                                      hasNeighbourScreen: true, now: start.addingTimeInterval(0.3))
        #expect(!r5)
    }

    @Test func ignoresPointerOutsideDockSpan() {
        var trigger = EdgeTrigger(edge: .left)
        let r6 = trigger.shouldReveal(pointer: CGPoint(x: 0, y: 50), screen: primary, dockSpan: span,
                                      hasNeighbourScreen: false, now: start)
        #expect(!r6)
        let r7 = trigger.shouldReveal(pointer: CGPoint(x: 0, y: 500), screen: primary, dockSpan: span,
                                     hasNeighbourScreen: false, now: start)
        #expect(r7)
    }

    @Test func topEdgeWaitsBecauseOfMenuBar() {
        var trigger = EdgeTrigger(edge: .top)
        let topSpan: ClosedRange<CGFloat> = 400...1100
        let atTop = CGPoint(x: 700, y: 981.5)
        let first = trigger.shouldReveal(pointer: atTop, screen: primary, dockSpan: topSpan,
                                         hasNeighbourScreen: false, now: start)
        #expect(!first)
        let rested = trigger.shouldReveal(pointer: atTop, screen: primary, dockSpan: topSpan,
                                          hasNeighbourScreen: false, now: start.addingTimeInterval(0.3))
        #expect(rested)
    }

    @Test func topEdgeIgnoresPointerOutsideSpan() {
        var trigger = EdgeTrigger(edge: .top)
        let revealed = trigger.shouldReveal(pointer: CGPoint(x: 100, y: 982), screen: primary, dockSpan: 400...1100,
                                            hasNeighbourScreen: false, now: start.addingTimeInterval(5))
        #expect(!revealed)
    }

    @Test func pointerPushedAgainstTopKeepsDockOpen() {
        // Regression: the very top row (y == screen.maxY) used to fall outside, so the dock hid
        // while the pointer was still resting at the edge.
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let dock = CGRect(x: 809, y: 1009, width: 110, height: 74)
        let trigger = EdgeTrigger(edge: .top)
        let open = { (x: CGFloat, y: CGFloat) in trigger.keepsOpen(pointer: CGPoint(x: x, y: y), dock: dock, screen: screen, slack: 8) }
        #expect(open(864, 1117))   // resting on the edge above the dock
        #expect(open(864, 1100))   // in the menu bar between dock and edge
        #expect(open(600, 1117))   // resting on the edge in the widened reveal span
        #expect(!open(600, 1100))  // using the menu bar away from the dock lets it hide
        #expect(!open(300, 1117))  // outside the reveal span
        #expect(!open(864, 900))   // below the dock
    }

    @Test func pointerAtSideEdgesKeepsDockOpen() {
        let right = CGRect(x: 1430, y: 300, width: 82, height: 400)
        #expect(EdgeTrigger(edge: .right).keepsOpen(pointer: CGPoint(x: 1511.9, y: 500), dock: right, screen: primary, slack: 8))
        let left = CGRect(x: 0, y: 300, width: 82, height: 400)
        #expect(EdgeTrigger(edge: .left).keepsOpen(pointer: CGPoint(x: 0, y: 500), dock: left, screen: primary, slack: 8))
        #expect(!EdgeTrigger(edge: .left).keepsOpen(pointer: CGPoint(x: 400, y: 500), dock: left, screen: primary, slack: 8))
    }

    @Test func smallDockGetsWiderRevealSpan() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let span = EdgeTrigger(edge: .top).revealSpan(dock: CGRect(x: 809, y: 1009, width: 110, height: 74), screen: screen)
        #expect(span.upperBound - span.lowerBound == 576)
        #expect(span.contains(864))
        #expect(span.contains(600))
    }

    @Test func revealSpanStaysOnScreenAndKeepsLargeDocks() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let nearEdge = EdgeTrigger(edge: .top).revealSpan(dock: CGRect(x: 0, y: 1009, width: 60, height: 74), screen: screen)
        #expect(nearEdge.lowerBound == 0)
        let tall = EdgeTrigger(edge: .left).revealSpan(dock: CGRect(x: 0, y: 100, width: 82, height: 900), screen: screen)
        #expect(tall == 100...1000)
    }

    @Test func detectsScreenAboveForTopEdge() {
        let above = CGRect(x: 0, y: 982, width: 1512, height: 982)
        #expect(EdgeTrigger(edge: .top).hasNeighbour(of: primary, among: [primary, above]))
        #expect(!EdgeTrigger(edge: .top).hasNeighbour(of: primary, among: [primary, external]))
    }

    @Test func detectsNeighbourOnlyOnDockEdge() {
        let screens = [primary, external]
        #expect(EdgeTrigger(edge: .right).hasNeighbour(of: primary, among: screens))
        #expect(!EdgeTrigger(edge: .left).hasNeighbour(of: primary, among: screens))
        let above = CGRect(x: 0, y: 982, width: 1512, height: 982)
        #expect(!EdgeTrigger(edge: .right).hasNeighbour(of: primary, among: [primary, above]))
    }
}
