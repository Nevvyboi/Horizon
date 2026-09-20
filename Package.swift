// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Horizon",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Horizon",
            path: "Sources/Horizon"
        )
    ]
)
