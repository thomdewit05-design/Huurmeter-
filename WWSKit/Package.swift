// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WWSKit",
    defaultLocalization: "nl",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WWSKit", targets: ["WWSKit"]),
    ],
    targets: [
        .target(
            name: "WWSKit",
            resources: [.copy("rules")]
        ),
        .testTarget(
            name: "WWSKitTests",
            dependencies: ["WWSKit"],
            path: "Tests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
