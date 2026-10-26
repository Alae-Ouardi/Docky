import Foundation
import Testing
@testable import DockyCore

struct DockConfigTests {
    let a = DockItem(kind: .app, path: "/Applications/A.app")
    let b = DockItem(kind: .app, path: "/Applications/B.app")
    let c = DockItem(kind: .folder, path: "/Users/test/Downloads")

    var config: DockConfig {
        DockConfig(left: SideDockConfig(isEnabled: true, items: [a, b]), right: SideDockConfig(items: [c]))
    }

    @Test func addingSkipsDuplicatesAndKeepsOriginal() {
        let original = config
        let updated = original.adding([DockItem(kind: .app, path: a.path), c], to: .left)
        #expect(updated.left.items.map(\.path) == [a.path, b.path, c.path])
        #expect(original.left.items.count == 2)
    }

    @Test func addingAtIndexClamps() {
        let updated = config.adding([c], to: .left, at: 99)
        #expect(updated.left.items.last == c)
        let front = config.adding([c], to: .left, at: -5)
        #expect(front.left.items.first == c)
    }

    @Test func removingDeletesFromAnyEdge() {
        let updated = config.removing(itemID: c.id)
        #expect(updated.right.items.isEmpty)
        #expect(updated.left.items == [a, b])
    }

    @Test func movingWithinSameEdgeForward() {
        // Drop A after B: destination index 2 in the pre-removal list.
        let updated = config.moving(itemID: a.id, to: .left, at: 2)
        #expect(updated.left.items == [b, a])
    }

    @Test func movingWithinSameEdgeBackward() {
        let updated = config.moving(itemID: b.id, to: .left, at: 0)
        #expect(updated.left.items == [b, a])
    }

    @Test func movingAcrossEdges() {
        let updated = config.moving(itemID: a.id, to: .right, at: 0)
        #expect(updated.left.items == [b])
        #expect(updated.right.items == [a, c])
    }

    @Test func movingToTopDock() {
        let updated = config.moving(itemID: b.id, to: .top, at: 0)
        #expect(updated.top.items == [b])
        #expect(updated.left.items == [a])
    }

    @Test func decodesConfigWithoutTopDock() throws {
        let json = #"{"left":{"isEnabled":true},"right":{}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DockConfig.self, from: json)
        #expect(decoded.top == SideDockConfig())
        #expect(decoded.left.isEnabled)
    }

    @Test func movingUnknownItemIsNoOp() {
        #expect(config.moving(itemID: UUID(), to: .right, at: 0) == config)
    }

    @Test func droppingOnlyTouchesDestinationDock() {
        // Moving between docks removes from the source explicitly; a drop never steals.
        let updated = config.dropping([URL(fileURLWithPath: c.path)], on: .left, at: 0)
        #expect(updated.left.items.map(\.path) == [c.path, a.path, b.path])
        #expect(updated.right.items == [c])
    }

    @Test func droppingReordersWithinDockKeepingIdentity() {
        let updated = config.dropping([URL(fileURLWithPath: a.path)], on: .left, at: 2)
        #expect(updated.left.items == [b, a])
    }

    @Test func placingIgnoresDuplicatePathsInOneDrop() {
        let x = DockItem(kind: .file, path: "/tmp/x.txt")
        #expect([a].placing([x, x], at: nil).map(\.path) == [a.path, x.path])
    }

    @Test func droppingNewPathsInsertsInOrder() {
        let x = URL(fileURLWithPath: "/tmp/x.txt")
        let y = URL(fileURLWithPath: "/tmp/y.txt")
        let updated = config.dropping([x, y], on: .left, at: 1)
        #expect(updated.left.items.map(\.path) == [a.path, x.path, y.path, b.path])
    }

    @Test func droppingWithoutIndexAppends() {
        let updated = config.dropping([URL(fileURLWithPath: a.path)], on: .left, at: nil)
        #expect(updated.left.items == [b, a])
    }

    @Test func nativeLayoutAddingSortsBySectionAndDedupes() {
        let layout = NativeDockLayout(apps: [a]).adding([a, b, c])
        #expect(layout.apps == [a, b])
        #expect(layout.others == [c])
        #expect(layout.removing(paths: [b.path]).apps == [a])
    }

    @Test func iconSizeIsClamped() {
        #expect(SideDockConfig(iconSize: 500).iconSize == SideDockConfig.iconSizeRange.upperBound)
        #expect(SideDockConfig(iconSize: 1).iconSize == SideDockConfig.iconSizeRange.lowerBound)
    }

    @Test func decodesPartialJSONWithDefaults() throws {
        let json = #"{"left":{"isEnabled":true}}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DockConfig.self, from: json)
        #expect(decoded.left.isEnabled)
        #expect(decoded.left.visibility == .alwaysVisible)
        #expect(decoded.left.iconSize == SideDockConfig.defaultIconSize)
        #expect(decoded.right == SideDockConfig())
    }

    @Test func labeledTileCountIncludesFoldersAndShelves() {
        let file = DockItem(kind: .file, path: "/Users/test/notes.txt")
        let shelf = Shelf(name: "Inbox", folderPath: "/Users/test/Shelf/Inbox")
        let dock = SideDockConfig(items: [a, c, file], shelves: [shelf])
        #expect(dock.labeledTileCount == 2)
        #expect(SideDockConfig(items: [a, b]).labeledTileCount == 0)
    }
}
