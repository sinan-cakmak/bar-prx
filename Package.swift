// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MITMMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MITMMenuBar",
            path: "Sources/MITMMenuBar",
            exclude: ["Resources/Info.plist"]
        )
    ]
)
