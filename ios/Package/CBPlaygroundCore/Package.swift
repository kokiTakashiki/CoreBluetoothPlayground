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
        // サプライチェーン対策でタグではなくコミット SHA で固定する（D-008 と同方針）。
        .package(url: "https://github.com/kean/Pulse", revision: "a4e5bc2b0439552d4ff5fc9667c389be6ef5bd52"), // 5.2.2
    ],
    targets: [
        .target(
            name: "CBPlaygroundCore",
            dependencies: [
                .product(name: "Pulse", package: "Pulse"),
            ]
        ),
        .testTarget(
            name: "CBPlaygroundCoreTests",
            dependencies: ["CBPlaygroundCore"]
        ),
    ]
)
