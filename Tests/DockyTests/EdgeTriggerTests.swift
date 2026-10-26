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
