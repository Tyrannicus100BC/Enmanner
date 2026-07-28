// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "EnmannerLauncher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "EnmannerCore", targets: ["EnmannerCore"]),
        .executable(name: "EnmannerLauncher", targets: ["EnmannerLauncher"]),
        .executable(name: "enmanner-validator", targets: ["EnmannerValidator"])
    ],
    targets: [
        .target(name: "EnmannerCore"),
        .executableTarget(
            name: "EnmannerLauncher",
            dependencies: ["EnmannerCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit")
            ]
        ),
        .executableTarget(
            name: "EnmannerValidator",
            dependencies: ["EnmannerCore"]
        ),
        .testTarget(
            name: "EnmannerCoreTests",
            dependencies: ["EnmannerCore"]
        )
    ]
)
