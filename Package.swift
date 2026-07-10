// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SelectionSpeaker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SelectionSpeaker", targets: ["SelectionSpeaker"]),
        .library(name: "SelectionSpeakerCore", targets: ["SelectionSpeakerCore"])
    ],
    targets: [
        .target(name: "SelectionSpeakerCore"),
        .executableTarget(
            name: "SelectionSpeaker",
            dependencies: ["SelectionSpeakerCore"]
        ),
        .testTarget(
            name: "SelectionSpeakerCoreTests",
            dependencies: ["SelectionSpeakerCore"]
        )
    ]
)
