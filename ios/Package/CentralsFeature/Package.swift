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
    ],
    targets: [
        .target(
            name: "CentralsFeature",
            dependencies: [
                .product(name: "CBPlaygroundCore", package: "CBPlaygroundCore"),
            ]
        ),
        .testTarget(
            name: "CentralsFeatureTests",
            dependencies: ["CentralsFeature"]
        ),
    ]
)
