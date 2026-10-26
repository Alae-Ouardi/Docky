import Foundation
import DockyCore

enum NativeDockError: LocalizedError {
    case backupFailed(String)
    case writeFailed
    case restartFailed(String)

    var errorDescription: String? {
        switch self {
        case .backupFailed(let reason): "Could not back up the current Dock: \(reason)"
        case .writeFailed: "Could not save the Dock preferences."
        case .restartFailed(let reason): "The Dock preferences were saved but the Dock did not restart: \(reason)"
        }
    }
}

/// Reads and writes the pinned items of the native macOS Dock (`com.apple.dock`).
enum NativeDockService {
    private static let domain = "com.apple.dock" as CFString

    static var backupFolder: URL {
        ConfigStore.supportFolder.appendingPathComponent("Dock Backups", isDirectory: true)
    }

    static func load() -> NativeDockLayout {
        NativeDockLayout(
            apps: NativeDockPlist.items(from: tiles(for: NativeDockPlist.appsKey)),
            others: NativeDockPlist.items(from: tiles(for: NativeDockPlist.othersKey))
        )
    }

    /// Backs up the current Dock preferences, writes the new layout and restarts the Dock.
    /// Returns the backup file location.
    @discardableResult
    static func apply(_ layout: NativeDockLayout) throws -> URL {
        let backup = try makeBackup()
        let apps = NativeDockPlist.tiles(for: layout.apps, reusing: tiles(for: NativeDockPlist.appsKey))
        let others = NativeDockPlist.tiles(for: layout.others, reusing: tiles(for: NativeDockPlist.othersKey))

        CFPreferencesSetAppValue(NativeDockPlist.appsKey as CFString, apps as CFArray, domain)
        CFPreferencesSetAppValue(NativeDockPlist.othersKey as CFString, others as CFArray, domain)
        guard CFPreferencesAppSynchronize(domain) else { throw NativeDockError.writeFailed }

        do {
            try run("/usr/bin/killall", ["Dock"])
        } catch {
            throw NativeDockError.restartFailed(error.localizedDescription)
        }
        return backup
    }

    /// Puts back a backup made by `apply` and restarts the Dock.
    static func restore(_ backup: URL) throws {
        try run("/usr/bin/defaults", ["import", "com.apple.dock", backup.path])
        try run("/usr/bin/killall", ["Dock"])
    }

    private static func tiles(for key: String) -> [NativeDockPlist.Tile] {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue(key as CFString, domain) as? [NativeDockPlist.Tile] ?? []
    }

    private static func makeBackup() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let file = backupFolder.appendingPathComponent("com.apple.dock_\(formatter.string(from: Date())).plist")
        do {
            try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
            try run("/usr/bin/defaults", ["export", "com.apple.dock", file.path])
        } catch {
            throw NativeDockError.backupFailed(error.localizedDescription)
        }
        return file
    }

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CocoaError(.executableLoad, userInfo: [
                NSLocalizedDescriptionKey: "\(tool) exited with status \(process.terminationStatus)"
            ])
        }
    }
}
