#if DEBUG
import AppKit
import DockyCore
import SwiftUI

/// Renders the README screenshots from sample data (never the user's own Dock or files).
/// Debug builds only: `Docky --render-screenshots <output-dir>`.
@MainActor
enum ScreenshotRenderer {
    static var outputDirectory: URL? {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--render-screenshots"), flag + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[flag + 1], isDirectory: true)
    }

    static func run(to output: URL) {
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("DockyScreenshots-\(UUID().uuidString)")
        let shelf = Shelf(name: "Inbox", folderPath: workspace.appendingPathComponent("Shelf/Inbox").path)
        // Settings lists shelves by path; show the default ~/Shelf location rather than the temp folder.
        let shelves = ["Inbox", "Screenshots"].map { Shelf.named($0) }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try SampleFiles.populate(shelf.folderURL)
        } catch {
            fatalError("Could not prepare screenshot workspace: \(error)")
        }

        let state = AppState(
            store: ConfigStore(fileURL: workspace.appendingPathComponent("config.json")),
            nativeDock: NativeDockEditor(source: { SampleData.nativeDock })
        )
        state.update { _ in SampleData.config(shelves: shelves) }

        let shots: [(String, CGSize, AnyView)] = [
            ("hero", CGSize(width: 1440, height: 900), AnyView(HeroScene(shelf: shelf).environment(state))),
            ("settings", CGSize(width: 1480, height: 860),
             AnyView(WindowFrame(title: "Docky") { SettingsView() }.environment(state))),
            ("shelf", CGSize(width: 520, height: 470),
             AnyView(Backdrop { ShelfCard(shelf: shelf) }.environment(state))),
        ]

        // Give Quick Look thumbnails and lists time to load before capturing.
        let windows = shots.map { name, size, view in (name, host(view, size: size)) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            for (name, window) in windows {
                capture(window, to: output.appendingPathComponent("\(name).png"))
            }
            try? FileManager.default.removeItem(at: workspace)
            print("Screenshots written to \(output.path)")
            NSApp.terminate(nil)
        }
    }

    private static func host(_ view: AnyView, size: CGSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: -20_000, y: -20_000, width: size.width, height: size.height),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        window.orderFrontRegardless()
        return window
    }

    private static func capture(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.close()
    }
}

// MARK: - Sample data

private enum SampleData {
    static func app(_ name: String) -> DockItem {
        let candidates = ["/Applications", "/System/Applications", "/System/Applications/Utilities"]
            .map { "\($0)/\(name).app" }
        let path = candidates.first { FileManager.default.fileExists(atPath: $0) } ?? candidates[1]
        return DockItem(kind: .app, path: path)
    }

    static func config(shelves: [Shelf]) -> DockConfig {
        DockConfig(
            left: SideDockConfig(
                isEnabled: true, visibility: .alwaysVisible, iconSize: 52,
                items: ["Mail", "Messages", "Calendar", "Notes", "Podcasts"].map(app)
            ),
            top: SideDockConfig(
                isEnabled: true, visibility: .autoHide, iconSize: 40,
                items: ["Contacts", "Weather", "Clock", "Calculator", "TextEdit"].map(app)
            ),
            right: SideDockConfig(
                isEnabled: true, visibility: .autoHide, iconSize: 52,
                items: ["Music", "Photos", "Freeform"].map(app),
                shelves: shelves
            )
        )
    }

    static let nativeDock = NativeDockLayout(
        apps: ["Maps", "Reminders", "FaceTime", "App Store", "System Settings", "Preview"].map(app),
        others: [DockItem(kind: .folder, path: "/Applications")]
    )
}

private enum SampleFiles {
    static func populate(_ folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let images: [(String, [NSColor])] = [
            ("Sunset.png", [.systemOrange, .systemPink, .systemPurple]),
            ("Lagoon.png", [.systemTeal, .systemBlue, .systemIndigo]),
            ("Forest.png", [.systemGreen, .systemMint, .systemTeal]),
            ("Dune.png", [.systemYellow, .systemOrange, .systemBrown]),
            ("Aurora.png", [.systemPurple, .systemBlue, .systemGreen]),
        ]
        for (name, colors) in images {
            try image(colors).write(to: folder.appendingPathComponent(name))
        }
        try "Ideas for the weekend trip\n\n- Pack light\n- Book the cabin\n"
            .write(to: folder.appendingPathComponent("Trip notes.txt"), atomically: true, encoding: .utf8)
        try "# Project Docky\n\nShelves keep the desktop clean."
            .write(to: folder.appendingPathComponent("README draft.md"), atomically: true, encoding: .utf8)
    }

    private static func image(_ colors: [NSColor]) -> Data {
        let size = 600
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size * 3 / 4, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let rect = NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh)
        NSGradient(colors: colors)!.draw(in: rect, angle: -60)
        NSColor.white.withAlphaComponent(0.35).setFill()
        NSBezierPath(ovalIn: NSRect(x: 380, y: 260, width: 120, height: 120)).fill()
        NSColor.black.withAlphaComponent(0.18).setFill()
        let hills = NSBezierPath()
        hills.move(to: .zero)
        hills.curve(to: NSPoint(x: 600, y: 120), controlPoint1: NSPoint(x: 200, y: 260), controlPoint2: NSPoint(x: 380, y: 20))
        hills.line(to: NSPoint(x: 600, y: 0))
        hills.close()
        hills.fill()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }
}

// MARK: - Scenes

/// A desktop with the left, top and right docks, an open shelf and a mock of the native bottom Dock.
private struct HeroScene: View {
    let shelf: Shelf
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            Wallpaper()
            VStack(spacing: 0) {
                MenuBarMock()
                DockChrome(edge: .top)
                    .padding(.top, 6)
                HStack(alignment: .center, spacing: 18) {
                    DockChrome(edge: .left)
                    Spacer()
                    ShelfCard(shelf: shelf)
                    DockChrome(edge: .right)
                }
                .padding(.horizontal, 6)
                .frame(maxHeight: .infinity)
                BottomDockMock()
                    .padding(.bottom, 8)
            }
        }
    }
}

private struct DockChrome: View {
    let edge: DockEdge
    @Environment(AppState.self) private var state

    var body: some View {
        let dock = state.config[edge]
        let thickness = DockMetrics.thickness(for: dock, edge: edge)
        let length = DockMetrics.length(for: dock, edge: edge)
        DockView(edge: edge)
            .frame(width: edge.isHorizontal ? length : thickness, height: edge.isHorizontal ? thickness : length)
            .background(Glass(cornerRadius: DockMetrics.cornerRadius))
    }
}

private struct ShelfCard: View {
    let shelf: Shelf

    var body: some View {
        ShelfContentView(shelf: shelf)
            .fixedSize()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.3), radius: 24, y: 10)
            )
    }
}

private struct BottomDockMock: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(SampleData.nativeDock.apps) { item in
                Image(nsImage: ItemActions.icon(for: item.path))
                    .resizable()
                    .frame(width: 54, height: 54)
            }
            Divider().frame(height: 44)
            Image(nsImage: ItemActions.icon(for: "/Applications"))
                .resizable()
                .frame(width: 54, height: 54)
        }
        .padding(8)
        .background(Glass(cornerRadius: 20))
    }
}

private struct MenuBarMock: View {
    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "apple.logo")
            Text("Finder").fontWeight(.semibold)
            Text("File")
            Text("Edit")
            Text("View")
            Spacer()
            Image(systemName: "dock.rectangle")
            Image(systemName: "wifi")
            Text("Mon 9:41")
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(Color.black.opacity(0.18))
    }
}

private struct Glass: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.white.opacity(0.38))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }
}

private struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.36, green: 0.31, blue: 0.95), Color(red: 0.16, green: 0.55, blue: 0.93),
                         Color(red: 0.13, green: 0.76, blue: 0.86)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle().fill(Color.pink.opacity(0.45)).frame(width: 700).blur(radius: 140).offset(x: -380, y: 260)
            Circle().fill(Color.orange.opacity(0.35)).frame(width: 560).blur(radius: 140).offset(x: 460, y: -260)
        }
    }
}

/// Soft background with padding, used around single components.
private struct Backdrop<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Wallpaper()
            content
        }
    }
}

/// A macOS-style window (title bar with traffic lights) around the settings view.
private struct WindowFrame<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        Backdrop {
            VStack(spacing: 0) {
                ZStack {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                        Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                        Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25))
                        Spacer()
                    }
                    .frame(height: 12)
                    .padding(.leading, 14)
                }
                .frame(height: 30)
                Divider()
                content
            }
            .frame(width: 1380, height: 760)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.35), radius: 30, y: 14)
        }
    }
}
#endif
