// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ghbdtn",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "LayoutCore"),
        .executableTarget(name: "Ghbdtn", dependencies: ["LayoutCore"]),
        .testTarget(name: "LayoutCoreTests", dependencies: ["LayoutCore"]),
    ]
)
