// swift-tools-version:5.9
import PackageDescription

// Logica achter de schermen van de app, zonder UI-afhankelijkheden, zodat alles te testen is.
let package = Package(
    name: "HuurmeterCore",
    defaultLocalization: "nl",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HuurmeterCore", targets: ["HuurmeterCore"]),
    ],
    dependencies: [
        .package(path: "../WWSKit"),
    ],
    targets: [
        .target(name: "HuurmeterCore", dependencies: ["WWSKit"]),
        .testTarget(
            name: "HuurmeterCoreTests",
            dependencies: ["HuurmeterCore"],
            path: "Tests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
