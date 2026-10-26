import Foundation
import Testing
@testable import DockyCore

struct ShelfTests {
    let root: URL
    let source: URL
    let shelf: Shelf
    let files = ShelfFileManager()

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShelfTests-\(UUID().uuidString)", isDirectory: true)
        source = root.appendingPathComponent("Desktop", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        shelf = Shelf.named("Screenshots", root: root.appendingPathComponent("Shelf"))
    }

    private func makeFile(_ name: String, in folder: URL? = nil) throws -> URL {
        let url = (folder ?? source).appendingPathComponent(name)
        try Data(name.utf8).write(to: url)
        return url
    }

    @Test func namedSanitizesFolderName() {
        let named = Shelf.named("  Work/2026: Q4 ", root: URL(fileURLWithPath: "/tmp/root"))
        #expect(named.name == "Work-2026- Q4")
        #expect(named.folderPath == "/tmp/root/Work-2026- Q4")
        #expect(Shelf.named("   ").name == "Shelf")
    }

    @Test func moveCreatesFolderAndMovesFile() throws {
        let file = try makeFile("photo.jpg")
        try files.move([file], into: shelf)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(files.contents(of: shelf).map(\.lastPathComponent) == ["photo.jpg"])
        try? FileManager.default.removeItem(at: root)
    }

    @Test func moveRenamesOnConflict() throws {
        try files.ensureFolder(shelf.folderURL)
        _ = try makeFile("photo.jpg", in: shelf.folderURL)
        _ = try makeFile("photo 2.jpg", in: shelf.folderURL)
        try files.move([try makeFile("photo.jpg")], into: shelf)
        #expect(FileManager.default.fileExists(atPath: shelf.folderURL.appendingPathComponent("photo 3.jpg").path))
        try? FileManager.default.removeItem(at: root)
    }

    @Test func fileAlreadyOnShelfIsLeftAlone() throws {
        try files.ensureFolder(shelf.folderURL)
        let existing = try makeFile("notes.txt", in: shelf.folderURL)
        try files.move([existing], into: shelf)
        #expect(files.contents(of: shelf).count == 1)
        try? FileManager.default.removeItem(at: root)
    }

    @Test func missingSourceThrows() {
        let ghost = source.appendingPathComponent("ghost.png")
        #expect(throws: ShelfError.self) { try files.move([ghost], into: shelf) }
        try? FileManager.default.removeItem(at: root)
    }

    @Test func namedRejectsDotNames() {
        let root = URL(fileURLWithPath: "/tmp/root")
        #expect(Shelf.named("..", root: root).folderPath == "/tmp/root/Shelf")
        #expect(Shelf.named(".", root: root).folderPath == "/tmp/root/Shelf")
        #expect(Shelf.named(".hidden", root: root).name == "hidden")
    }

    @Test func refusesUnsafeItems() {
        let folder = URL(fileURLWithPath: "/Users/test/Shelf/Work")
        let refusal = { (path: String) in ShelfFileManager.refusal(for: URL(fileURLWithPath: path), shelfFolder: folder) }
        #expect(refusal("/Users/test/Downloads/Tool.app") != nil)
        #expect(refusal("/Users/test/Shelf") != nil)
        #expect(refusal("/Users/test/Shelf/Work") != nil)
        #expect(refusal("/Applications/Notes.txt") != nil)
        #expect(refusal("/") != nil)
        #expect(refusal("/Users/test/Downloads/photo.jpg") == nil)
    }

    @Test func continuesPastFailuresAndReportsThem() throws {
        let good = try makeFile("good.txt")
        let ghost = source.appendingPathComponent("ghost.png")
        #expect(throws: ShelfError.self) { try files.move([ghost, good], into: shelf) }
        #expect(files.contents(of: shelf).map(\.lastPathComponent) == ["good.txt"])
        try? FileManager.default.removeItem(at: root)
    }

    @Test func sideConfigDecodesWithoutShelves() throws {
        let json = #"{"isEnabled":true}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SideDockConfig.self, from: json)
        #expect(decoded.shelves.isEmpty)
    }
}
