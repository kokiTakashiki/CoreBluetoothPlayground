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
        // サプライチェーン対策でタグではなくコミット SHA で固定する（D-008 と同方針）。
        .package(url: "https://github.com/kean/Pulse", revision: "a4e5bc2b0439552d4ff5fc9667c389be6ef5bd52"), // 5.2.2
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
