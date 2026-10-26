import Foundation
import Testing
@testable import DockyCore

struct NativeDockPlistTests {
    let safariTile: NativeDockPlist.Tile = [
        "GUID": 1234,
        "tile-type": "file-tile",
        "tile-data": [
            "bundle-identifier": "com.apple.Safari",
            "file-label": "Safari",
            "file-data": ["_CFURLString": "file:///Applications/Safari.app/", "_CFURLStringType": 15]
        ]
    ]

    let downloadsTile: NativeDockPlist.Tile = [
        "tile-type": "directory-tile",
        "tile-data": [
            "file-data": ["_CFURLString": "file:///Users/test/Downloads/", "_CFURLStringType": 15]
        ]
    ]

    @Test func parsesAppAndFolderTiles() {
        let items = NativeDockPlist.items(from: [safariTile, downloadsTile])
        #expect(items.map(\.kind) == [.app, .folder])
        #expect(items.map(\.path) == ["/Applications/Safari.app", "/Users/test/Downloads"])
    }

    @Test func skipsMalformedTiles() {
        let items = NativeDockPlist.items(from: [["tile-type": "spacer-tile"], safariTile])
        #expect(items.count == 1)
    }

    @Test func reusesExistingTileForUnchangedPath() {
        let item = DockItem(kind: .app, path: "/Applications/Safari.app")
        let tiles = NativeDockPlist.tiles(for: [item], reusing: [safariTile])
        #expect(tiles.first?["GUID"] as? Int == 1234)
    }

    @Test func keepsUnparsedTilesInPlace() {
        let spacer: NativeDockPlist.Tile = ["tile-type": "spacer-tile", "tile-data": [String: Any]()]
        let item = DockItem(kind: .app, path: "/Applications/Safari.app")
        let other = DockItem(kind: .app, path: "/Applications/Mail.app")
        let tiles = NativeDockPlist.tiles(for: [item, other], reusing: [safariTile, spacer])
        #expect(tiles.map { $0["tile-type"] as? String } == ["file-tile", "spacer-tile", "file-tile"])
    }

    @Test func buildsNewFolderTile() {
        let item = DockItem(kind: .folder, path: "/Users/test/Documents")
        let tile = NativeDockPlist.tiles(for: [item], reusing: []).first
        #expect(tile?["tile-type"] as? String == "directory-tile")
        let parsed = tile.flatMap(NativeDockPlist.item(from:))
        #expect(parsed?.path == item.path)
        #expect(parsed?.kind == .folder)
    }

    @Test func newAppTileRoundTrips() {
        let item = DockItem(kind: .app, path: "/Applications/Example.app")
        let tile = NativeDockPlist.newTile(for: item)
        #expect(tile["tile-type"] as? String == "file-tile")
        #expect(NativeDockPlist.item(from: tile)?.path == item.path)
    }
}
