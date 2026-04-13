// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorkStop",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WorkStop",
            path: "Sources"
        )
    ]
)
