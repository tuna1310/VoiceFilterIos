// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceFilter_iOS",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "VoiceFilter_iOS",
            targets: ["VoiceFilter_iOS"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VoiceFilter_iOS",
            path: "VoiceFilter_iOS"
        ),
        .testTarget(
            name: "VoiceFilter_iOSTests",
            dependencies: ["VoiceFilter_iOS"],
            path: "VoiceFilter_iOSTests"
        ),
    ]
)
