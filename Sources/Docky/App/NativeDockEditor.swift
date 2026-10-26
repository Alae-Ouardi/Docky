import DockyCore
import Foundation
import Observation
import SwiftUI

/// Draft of the native Dock's pinned items. Changes only reach the Dock on `apply()`.
@MainActor
@Observable
final class NativeDockEditor {
    var draft = NativeDockLayout()
    private(set) var saved = NativeDockLayout()
    private(set) var lastBackup: URL?

    @ObservationIgnored private let source: () -> NativeDockLayout

    var isDirty: Bool { draft != saved }

    init(source: @escaping () -> NativeDockLayout = NativeDockService.load) {
        self.source = source
    }

    func reload() {
        saved = source()
        draft = saved
    }

    func add(_ urls: [URL]) {
        draft = draft.adding(urls.map(DockItem.init(url:)))
    }


    /// Drops files into a section; already-pinned paths are moved instead of duplicated.
    func place(_ urls: [URL], in section: NativeDockLayout.Section, at index: Int?) {
        draft = draft.placing(urls.map(DockItem.init(url:)), in: section, at: index)
    }

    func remove(paths: Set<String>) {
        draft = draft.removing(paths: paths)
    }

    func restore(_ backup: URL) throws {
        try NativeDockService.restore(backup)
        lastBackup = nil
        reload()
    }

    func apply() throws {
        lastBackup = try NativeDockService.apply(draft)
        saved = draft
    }
}
