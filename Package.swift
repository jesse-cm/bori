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
        // Shared by the app and the privileged helper: the XPC protocol
        // and pure /etc/hosts text editing.
        .target(name: "BoriHelperCore", path: "Sources/BoriHelperCore"),
        // The root daemon, registered via SMAppService.
        .executableTarget(
            name: "BoriHelper",
            dependencies: ["BoriHelperCore"],
            path: "Sources/BoriHelper"
        ),
        .executableTarget(
            name: "BoriApp",
            dependencies: ["BoriEngine", "BoriHelperCore"],
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
        .testTarget(
            name: "BoriHelperCoreTests",
            dependencies: ["BoriHelperCore"],
            path: "Tests/BoriHelperCoreTests"
        ),
    ]
)
