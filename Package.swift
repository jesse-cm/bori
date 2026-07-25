// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Bori",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Bori", targets: ["BoriApp"]),
        .library(name: "BoriEngine", targets: ["BoriEngine"]),
    ],
    targets: [
        // Pure session engine: states, config, schedules. No UI imports.
        .target(name: "BoriEngine", path: "Sources/BoriEngine"),
        .executableTarget(
            name: "BoriApp",
            dependencies: ["BoriEngine"],
            path: "Sources/BoriApp",
            resources: [
                .copy("Resources/theme.css"),
                .copy("Resources/bori-screen.js"),
            ]
        ),
        .testTarget(
            name: "BoriEngineTests",
            dependencies: ["BoriEngine"],
            path: "Tests/BoriEngineTests"
        ),
    ]
)
