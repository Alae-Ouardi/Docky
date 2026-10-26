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

    func remove(_ item: DockItem) {
        draft = draft.removing(itemID: item.id)
    }

    func move(_ section: WritableKeyPath<NativeDockLayout, [DockItem]>, from source: IndexSet, to destination: Int) {
        draft[keyPath: section].move(fromOffsets: source, toOffset: destination)
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
