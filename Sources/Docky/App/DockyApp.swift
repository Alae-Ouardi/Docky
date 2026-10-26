import DockyCore
import SwiftUI

@main
struct DockyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Docky", systemImage: "dock.rectangle") {
            MenuContent(openSettings: delegate.showSettings)
                .environment(delegate.state)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let state = AppState(store: AppDelegate.configStore)

    /// Debug builds can point at a throwaway config (`DOCKY_CONFIG=/path/config.json`) so
    /// end-to-end checks never touch the user's real layout.
    private static var configStore: ConfigStore {
        #if DEBUG
        if let path = ProcessInfo.processInfo.environment["DOCKY_CONFIG"] {
            return ConfigStore(fileURL: URL(fileURLWithPath: path))
        }
        #endif
        return ConfigStore()
    }
    private var dockManager: DockManager?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if let output = ScreenshotRenderer.outputDirectory {
            ScreenshotRenderer.run(to: output)
            return
        }
        #endif
        let manager = DockManager(state: state)
        state.onConfigChange = { [weak manager] config in manager?.sync(config) }
        manager.sync(state.config)
        dockManager = manager

        // Opening Docky from Finder or Launchpad shows its window; starting at login stays quiet.
        if !Self.launchedAsLoginItem(notification) {
            showSettings()
        }
    }

    /// Double-clicking Docky while it is already running brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func showSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        // Docky normally lives only in the menu bar; give it a Dock icon while the window is open.
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// Items moved into an unapplied bottom-Dock draft go back to their docks.
    func applicationWillTerminate(_ notification: Notification) {
        state.restoreStagedMoves()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeSettingsWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView().environment(state)))
        window.title = "Docky"
        window.setContentSize(NSSize(width: 1340, height: 720))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("DockySettings")
        return window
    }

    private static func launchedAsLoginItem(_ notification: Notification) -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
