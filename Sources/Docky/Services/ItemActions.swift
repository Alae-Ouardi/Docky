import AppKit
import DockyCore
import QuickLookThumbnailing

/// Opening, revealing and icons for files shown in the docks.
@MainActor
enum ItemActions {
    private static let iconCache = NSCache<NSString, NSImage>()

    static func open(_ item: DockItem) {
        if item.kind == .app {
            NSWorkspace.shared.openApplication(at: item.url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func icon(for path: String) -> NSImage {
        if let cached = iconCache.object(forKey: path as NSString) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        // Workspace icons report a 32pt size; a larger size makes SwiftUI pick the
        // high-resolution representation instead of upscaling the small one.
        icon.size = NSSize(width: 256, height: 256)
        iconCache.setObject(icon, forKey: path as NSString)
        return icon
    }

    /// Quick Look thumbnail for images/videos/documents, falling back to the Finder icon.
    static func thumbnail(for url: URL, size: CGFloat) async -> NSImage {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: CGSize(width: size, height: size), scale: scale, representationTypes: .thumbnail
        )
        if let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            return thumbnail.nsImage
        }
        return icon(for: url.path)
    }
}
