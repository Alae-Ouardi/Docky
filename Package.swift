// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Docky",
    platforms: [.macOS("15.0")],
    products: [
        .executable(name: "Docky", targets: ["Docky"])
    ],
    targets: [
        .target(
            name: "DockyCore",
            path: "Sources/DockyCore"
        ),
        .executableTarget(
            name: "Docky",
            dependencies: ["DockyCore"],
            path: "Sources/Docky"
        ),
        .testTarget(
            name: "DockyTests",
            dependencies: ["DockyCore"],
            path: "Tests/DockyTests"
        )
    ]
)
