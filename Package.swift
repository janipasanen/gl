// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "gl",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "gl", targets: ["gl"]),
        .library(name: "GitLabCore", targets: ["GitLabCore"]),
    ],
    targets: [
        .executableTarget(
            name: "gl",
            dependencies: ["GitLabCore"],
            path: "Sources/gl"
        ),
        .target(
            name: "GitLabCore",
            path: "Sources/GitLabCore"
        ),
        .testTarget(
            name: "GitLabCoreTests",
            dependencies: ["GitLabCore"],
            path: "Tests/GitLabCoreTests"
        ),
    ]
)
