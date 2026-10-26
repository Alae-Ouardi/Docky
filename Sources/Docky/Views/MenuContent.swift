import DockyCore
import SwiftUI

/// Menu bar menu: quick toggles plus the way into the customization window.
struct MenuContent: View {
    let openSettings: () -> Void

    @Environment(AppState.self) private var state

    var body: some View {
        // Errors also surface here so they are not lost while Settings is closed.
        if let error = state.lastError {
            Text("⚠︎ \(error)")
            Button("Dismiss Warning") { state.lastError = nil }
            Divider()
        }

        Button("Customize Docky…", action: openSettings)
            .keyboardShortcut(",")

        Divider()

        ForEach(DockEdge.allCases, id: \.self) { edge in
            Toggle("\(edge.title) Dock", isOn: Binding(
                get: { state.config[edge].isEnabled },
                set: { enabled in state.updateSide(edge) { $0.isEnabled = enabled } }
            ))
        }

        Toggle("Launch at Login", isOn: Binding(
            get: { state.launchAtLogin },
            set: { state.setLaunchAtLogin($0) }
        ))

        Divider()

        Button("Quit Docky") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
