// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Slide",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SlideCore"),
        .executableTarget(name: "Slide", dependencies: ["SlideCore"]),
        .testTarget(name: "SlideCoreTests", dependencies: ["SlideCore"]),
    ]
)
