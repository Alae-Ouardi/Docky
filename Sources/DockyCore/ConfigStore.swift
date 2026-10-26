import Foundation

public enum ConfigStoreError: Error, Equatable {
    case unreadable(String)
    case unwritable(String)
}

/// Persists the dock configuration as JSON on disk.
public struct ConfigStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL = ConfigStore.defaultFileURL) {
        self.fileURL = fileURL
    }

    public static var supportFolder: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Docky", isDirectory: true)
    }

    public static var defaultFileURL: URL {
        supportFolder.appendingPathComponent("config.json")
    }

    /// Returns the saved config, or a default one when nothing has been saved yet.
    public func load() throws(ConfigStoreError) -> DockConfig {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return DockConfig() }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(DockConfig.self, from: data)
        } catch {
            throw .unreadable(error.localizedDescription)
        }
    }

    /// Moves an unreadable config aside so the next save cannot overwrite the user's layout.
    /// Returns where it was moved.
    @discardableResult
    public func quarantine(now: Date = Date()) -> URL? {
        let stamp = Int(now.timeIntervalSince1970)
        let destination = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    public func save(_ config: DockConfig) throws(ConfigStoreError) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(config).write(to: fileURL, options: .atomic)
        } catch {
            throw .unwritable(error.localizedDescription)
        }
    }
}
