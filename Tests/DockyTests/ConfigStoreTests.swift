import Foundation
import Testing
@testable import DockyCore

struct ConfigStoreTests {
    let directory: URL
    let store: ConfigStore

    init() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DockyTests-\(UUID().uuidString)", isDirectory: true)
        store = ConfigStore(fileURL: directory.appendingPathComponent("nested/config.json"))
    }

    @Test func loadReturnsDefaultWhenMissing() throws {
        #expect(try store.load() == DockConfig())
    }

    @Test func saveThenLoadRoundTrips() throws {
        let config = DockConfig(
            left: SideDockConfig(isEnabled: true, visibility: .autoHide, iconSize: 64,
                                 items: [DockItem(kind: .app, path: "/Applications/Safari.app")]),
            right: SideDockConfig(isEnabled: true, items: [DockItem(kind: .folder, path: "/tmp")])
        )
        try store.save(config)
        #expect(try store.load() == config)
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func corruptFileThrowsUnreadable() throws {
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)
        #expect(throws: ConfigStoreError.self) { try store.load() }

        let moved = store.quarantine(now: Date(timeIntervalSince1970: 42))
        #expect(moved?.lastPathComponent == "config.corrupt-42.json")
        #expect(try store.load() == DockConfig())
        try? FileManager.default.removeItem(at: directory)
    }
}
