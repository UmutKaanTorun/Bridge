// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KopruCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KopruCore", targets: ["KopruCore"]),
    ],
    targets: [
        .target(name: "KopruCore"),
        .testTarget(name: "KopruCoreTests", dependencies: ["KopruCore"]),
    ]
)
