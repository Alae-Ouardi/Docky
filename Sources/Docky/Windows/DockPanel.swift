import AppKit
import SwiftUI

/// Borderless floating panel that never steals focus from the app you are working in.
final class DockPanel: NSPanel {
    init<Content: View>(rootView: Content) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        contentView = Self.makeBackground(content: FirstMouseHostingView(rootView: rootView))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private static func makeBackground(content: NSView) -> NSView {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = DockMetrics.cornerRadius
            glass.contentView = content
            return glass
        }
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = DockMetrics.cornerRadius
        effect.layer?.masksToBounds = true
        content.frame = effect.bounds
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)
        return effect
    }
}

/// Lets the first click on a dock icon act immediately instead of only focusing the panel.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
