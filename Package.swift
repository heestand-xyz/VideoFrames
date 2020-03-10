// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "VideoFrames",
    products: [
        .library(name: "VideoFrames", targets: ["VideoFrames"]),
    ],
    targets: [
        .target(name: "VideoFrames", dependencies: []),
        .testTarget(name: "VideoFramesTests", dependencies: ["VideoFrames"]),
    ]
)
