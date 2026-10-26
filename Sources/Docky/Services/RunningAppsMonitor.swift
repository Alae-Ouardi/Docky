import AppKit
import DockyCore
import Observation

/// Tracks which applications are running so docks can show a running indicator.
@MainActor
@Observable
final class RunningAppsMonitor {
    private(set) var runningBundleIDs: Set<String> = []
    private(set) var runningPaths: Set<String> = []

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    /// Per pinned path: its resolved path and bundle ID, so rendering never touches the disk twice.
    @ObservationIgnored private var identityCache: [String: (path: String, bundleID: String?)] = [:]

    init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        let names = [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    func isRunning(_ item: DockItem) -> Bool {
        guard item.kind == .app else { return false }
        let identity = identity(for: item)
        return runningPaths.contains(identity.path) || identity.bundleID.map(runningBundleIDs.contains) == true
    }

    func application(for item: DockItem) -> NSRunningApplication? {
        let identity = identity(for: item)
        return NSWorkspace.shared.runningApplications.first { app in
            app.bundleURL.map { Self.normalized($0.path) } == identity.path
                || (identity.bundleID != nil && app.bundleIdentifier == identity.bundleID)
        }
    }

    private func refresh() {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        runningBundleIDs = Set(apps.compactMap(\.bundleIdentifier))
        runningPaths = Set(apps.compactMap { $0.bundleURL.map { Self.normalized($0.path) } })
    }

    private func identity(for item: DockItem) -> (path: String, bundleID: String?) {
        if let cached = identityCache[item.path] { return cached }
        let identity = (path: Self.normalized(item.path), bundleID: Bundle(path: item.path)?.bundleIdentifier)
        identityCache[item.path] = identity
        return identity
    }

    private static func normalized(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }
}
