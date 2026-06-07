// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CBPlaygroundCore",
    defaultLocalization: "ja",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "CBPlaygroundCore", targets: ["CBPlaygroundCore"]),
    ],
    dependencies: [
        // BLESession で `@BLELog` / `@DynamicBLELog` を使うためロギングパッケージへ依存する。
        // Pulse には依存せず、ログ取得は CBPlaygroundLogging のマクロ経由のみで行う規約。
        .package(path: "../CBPlaygroundLogging"),
    ],
    targets: [
        .target(
            name: "CBPlaygroundCore",
            dependencies: [
                .product(name: "CBPlaygroundLogging", package: "CBPlaygroundLogging"),
            ]
        ),
        .testTarget(
            name: "CBPlaygroundCoreTests",
            dependencies: ["CBPlaygroundCore"]
        ),
    ]
)
