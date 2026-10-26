import AppKit
import DockyCore

/// Creates, updates and removes the side dock windows to match the configuration.
@MainActor
final class DockManager {
    private let state: AppState
    private var controllers: [DockEdge: DockWindowController] = [:]
    private var screenObserver: NSObjectProtocol?

    init(state: AppState) {
        self.state = state
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.controllers.values.forEach { $0.layout() } }
        }
    }

    func sync(_ config: DockConfig) {
        for edge in DockEdge.allCases {
            let side = config[edge]
            if side.isEnabled {
                let controller = controllers[edge] ?? DockWindowController(edge: edge, state: state)
                controllers[edge] = controller
                controller.apply(side)
            } else {
                controllers.removeValue(forKey: edge)?.close()
            }
        }
    }
}
