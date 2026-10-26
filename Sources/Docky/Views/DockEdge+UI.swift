import DockyCore
import SwiftUI

extension DockEdge {
    /// Popovers open away from the screen edge the dock sits on.
    var popoverArrowEdge: Edge {
        switch self {
        case .left: .trailing
        case .top: .bottom
        case .right: .leading
        }
    }

    var symbolName: String {
        switch self {
        case .left: "sidebar.left"
        case .top: "rectangle.tophalf.inset.filled"
        case .right: "sidebar.right"
        }
    }
}
