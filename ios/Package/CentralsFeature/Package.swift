// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CentralsFeature",
    defaultLocalization: "ja",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "CentralsFeature", targets: ["CentralsFeature"]),
    ],
    dependencies: [
        .package(path: "../CBPlaygroundCore"),
        .package(path: "../CBPlaygroundConsole"),
        .package(path: "../CBPlaygroundLogging"),
    ],
    targets: [
        .target(
            name: "CentralsFeature",
            dependencies: [
                .product(name: "CBPlaygroundCore", package: "CBPlaygroundCore"),
                .product(name: "CBPlaygroundConsole", package: "CBPlaygroundConsole"),
                .product(name: "CBPlaygroundLogging", package: "CBPlaygroundLogging"),
            ]
        ),
        .testTarget(
            name: "CentralsFeatureTests",
            dependencies: ["CentralsFeature"]
        ),
    ]
)
