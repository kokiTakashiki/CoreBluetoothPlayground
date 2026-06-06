// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CBPlaygroundConsole",
    defaultLocalization: "ja",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "CBPlaygroundConsole", targets: ["CBPlaygroundConsole"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Pulse", exact: "5.2.2"),
    ],
    targets: [
        .target(
            name: "CBPlaygroundConsole",
            dependencies: [
                .product(name: "PulseUI", package: "Pulse"),
            ]
        ),
    ]
)
