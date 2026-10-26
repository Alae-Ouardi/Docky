import AppKit
import DockyCore
import Observation
import os

/// Single source of truth for the dock configuration; every change is persisted immediately.
@MainActor
@Observable
final class AppState {
    private(set) var config: DockConfig
    private(set) var launchAtLogin = LoginItemService.isEnabled
    /// Bumped whenever shelf files change so open shelf views reload.
    private(set) var shelfRevision = 0
    /// The shelf whose contents popover is open; auto-hide docks stay out while it is set.
    var openShelfID: UUID?
    var lastError: String?

    let running = RunningAppsMonitor()
    /// Unapplied edits to the macOS bottom Dock.
    let nativeDock: NativeDockEditor

    @ObservationIgnored var onConfigChange: ((DockConfig) -> Void)?
    /// Items moved from a Docky dock into the bottom-Dock draft that has not been applied yet.
    @ObservationIgnored private var stagedForBottom: [(edge: DockEdge, item: DockItem)] = []
    @ObservationIgnored private let store: ConfigStore
    @ObservationIgnored private let shelfFiles = ShelfFileManager()
    @ObservationIgnored private let logger = Logger(subsystem: "Docky", category: "AppState")

    init(store: ConfigStore = ConfigStore(), nativeDock: NativeDockEditor? = nil) {
        self.store = store
        self.nativeDock = nativeDock ?? NativeDockEditor()
        do {
            config = try store.load()
        } catch {
            config = DockConfig()
            // Keep the unreadable file so saving the defaults cannot destroy the user's layout.
            let kept = store.quarantine()
            lastError = "Your saved dock layout could not be read, so the defaults were loaded."
                + (kept.map { " The old file was kept as \($0.lastPathComponent)." } ?? "")
            logger.error("Config load failed: \(String(describing: error), privacy: .public)")
        }
    }

    func update(_ transform: (DockConfig) -> DockConfig) {
        let updated = transform(config)
        guard updated != config else { return }
        config = updated
        do {
            try store.save(updated)
        } catch {
            report("Your dock layout could not be saved.", error)
        }
        onConfigChange?(updated)
    }

    func updateSide(_ edge: DockEdge, _ change: (inout SideDockConfig) -> Void) {
        update { config in
            var copy = config
            change(&copy[edge])
            return copy
        }
    }

    func drop(_ urls: [URL], on edge: DockEdge, at index: Int?) {
        update { $0.dropping(urls, on: edge, at: index) }
    }

    // MARK: - Moving items between docks

    enum DropTarget: Equatable {
        case custom(DockEdge)
        case bottom(NativeDockLayout.Section)
    }

    /// The one place items move between docks: drops from the live docks, the customization
    /// columns and Finder, and every "Move to …" menu. Items leave their source dock (unless it
    /// is the destination, which just reorders) and land at `index` in the target.
    func move(_ payloads: [DockDragPayload], to target: DropTarget, at index: Int?) {
        var next = config
        for payload in payloads {
            guard case .custom(let source) = payload.source, target != .custom(source) else { continue }
            if case .bottom = target, let item = next[source].items.first(where: { $0.path == payload.path }) {
                stagedForBottom.append((source, item))
            }
            next = next.removing(paths: [payload.path], from: source)
        }
        let urls = payloads.map(\.url)
        switch target {
        case .custom(let edge):
            next = next.dropping(urls, on: edge, at: index)
            let fromBottom = Set(payloads.filter { $0.source == .bottom }.map(\.path))
            if !fromBottom.isEmpty { nativeDock.remove(paths: fromBottom) }
        case .bottom(let section):
            nativeDock.place(urls, in: section, at: index)
        }
        update { _ in next }
    }

    // MARK: - Bottom (macOS) Dock draft

    /// Loads the macOS Dock into the draft unless there are unapplied edits to keep.
    func loadBottomDockIfClean() {
        if !nativeDock.isDirty { nativeDock.reload() }
    }

    func applyBottomDock() {
        do {
            try nativeDock.apply()
            stagedForBottom = []
        } catch {
            report(error.localizedDescription, error)
        }
    }

    /// Discards the draft and puts items moved into it back on their Docky docks.
    func revertBottomDock() {
        restoreStagedMoves()
        nativeDock.reload()
    }

    func undoBottomDock(_ backup: URL) {
        do {
            try nativeDock.restore(backup)
        } catch {
            report(error.localizedDescription, error)
        }
    }

    /// Items moved from a Docky dock into a draft that was never applied go back where they
    /// came from, so a move can never lose them (called on revert and when Docky quits).
    func restoreStagedMoves() {
        guard !stagedForBottom.isEmpty else { return }
        let staged = stagedForBottom
        stagedForBottom = []
        update { config in staged.reduce(config) { $0.adding([$1.item], to: $1.edge) } }
    }

    func moveFiles(_ urls: [URL], to shelf: Shelf) {
        let files = shelfFiles
        Task {
            // Off the main actor: moves across volumes copy the data and can take a while.
            let result = await Task.detached { Result { () throws(ShelfError) in try files.move(urls, into: shelf) } }.value
            if case .failure(let error) = result {
                report(error.localizedDescription, error)
            }
            shelfRevision += 1
        }
    }

    func trash(_ url: URL) {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            report("\(url.lastPathComponent) could not be moved to the Trash.", error)
        }
        shelfRevision += 1
    }

    func shelfContents(_ shelf: Shelf) -> [URL] {
        shelfFiles.contents(of: shelf)
    }

    func addShelf(_ shelf: Shelf, to edge: DockEdge) {
        do {
            try shelfFiles.ensureFolder(shelf.folderURL)
        } catch {
            report(error.localizedDescription, error)
            return
        }
        updateSide(edge) { side in
            let path = shelf.folderURL.standardizedFileURL.path
            guard !side.shelves.contains(where: { $0.folderURL.standardizedFileURL.path == path }) else { return }
            side.shelves.append(shelf)
        }
    }

    /// Removes the shelf from the dock; its folder and files stay on disk.
    func removeShelf(_ shelf: Shelf, from edge: DockEdge) {
        if openShelfID == shelf.id { openShelfID = nil }
        updateSide(edge) { $0.shelves.removeAll { $0.id == shelf.id } }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemService.setEnabled(enabled)
        } catch {
            report("Launch at login could not be changed. Make sure Docky runs from its .app bundle.", error)
        }
        launchAtLogin = LoginItemService.isEnabled
    }

    func report(_ message: String, _ error: Error) {
        lastError = message
        logger.error("\(message, privacy: .public): \(String(describing: error), privacy: .public)")
    }
}
