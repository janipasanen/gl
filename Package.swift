// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "gl",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .executable(name: "gl", targets: ["gl"]),
        .library(name: "GitLabCore", targets: ["GitLabCore"]),
    ],
    targets: [
        .target(
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
