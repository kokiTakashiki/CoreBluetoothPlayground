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
        .package(path: "../CBPlaygroundMacros"),
    ],
    targets: [
        .target(
            name: "CentralsFeature",
            dependencies: [
                .product(name: "CBPlaygroundCore", package: "CBPlaygroundCore"),
                .product(name: "CBPlaygroundConsole", package: "CBPlaygroundConsole"),
                .product(name: "CBPlaygroundMacros", package: "CBPlaygroundMacros"),
            ]
        ),
        .testTarget(
            name: "CentralsFeatureTests",
            dependencies: ["CentralsFeature"]
        ),
    ]
)
