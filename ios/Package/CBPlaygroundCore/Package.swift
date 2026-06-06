// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CBPlaygroundCore",
    defaultLocalization: "ja",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "CBPlaygroundCore", targets: ["CBPlaygroundCore"]),
    ],
    targets: [
        .target(
            name: "CBPlaygroundCore"
        ),
        .testTarget(
            name: "CBPlaygroundCoreTests",
            dependencies: ["CBPlaygroundCore"]
        ),
    ]
)
