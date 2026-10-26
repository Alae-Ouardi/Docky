import Foundation
import Testing
@testable import DockyCore

struct NativeDockLayoutTests {
    let maps = DockItem(kind: .app, path: "/System/Applications/Maps.app")
    let notes = DockItem(kind: .app, path: "/System/Applications/Notes.app")
    let mail = DockItem(kind: .app, path: "/System/Applications/Mail.app")
    let downloads = DockItem(kind: .folder, path: "/Users/test/Downloads")

    var layout: NativeDockLayout { NativeDockLayout(apps: [maps, notes], others: [downloads]) }

    @Test func insertsNewAppAtIndex() {
        let placed = layout.placing([mail], in: .apps, at: 1)
        #expect(placed.apps == [maps, mail, notes])
    }

    @Test func reordersExistingAppWithoutDuplicating() {
        // Drop Maps after Notes: index 2 counted before Maps is removed.
        let placed = layout.placing([DockItem(kind: .app, path: maps.path)], in: .apps, at: 2)
        #expect(placed.apps.map(\.path) == [notes.path, maps.path])
        #expect(placed.apps.last?.id == maps.id)
    }

    @Test func appDroppedOnFolderSectionGoesToApps() {
        let placed = layout.placing([mail], in: .others, at: 0)
        #expect(placed.apps == [maps, notes, mail])
        #expect(placed.others == [downloads])
    }

    @Test func nilIndexAppends() {
        let placed = layout.placing([mail], in: .apps, at: nil)
        #expect(placed.apps.last == mail)
    }

    @Test func removingPaths() {
        let removed = layout.removing(paths: [maps.path, downloads.path])
        #expect(removed.apps == [notes])
        #expect(removed.others.isEmpty)
    }

    @Test func removingPathsFromOneEdge() {
        let config = DockConfig(left: SideDockConfig(items: [maps]), top: SideDockConfig(items: [maps, notes]))
        let updated = config.removing(paths: [maps.path], from: .top)
        #expect(updated.top.items == [notes])
        #expect(updated.left.items == [maps])
    }
}
