// swift-tools-version: 6.0
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "CBPlaygroundLogging",
    defaultLocalization: "ja",
    // macOS はマクロプラグインをビルドホスト上で動かすために必要（成果物の対象は iOS のみ）。
    platforms: [.iOS("26.0"), .macOS("13.0")],
    products: [
        .library(name: "CBPlaygroundLogging", targets: ["CBPlaygroundLogging"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax",
            revision: "4799286537280063c85a32f09884cfbca301b1a1"
        ), // 602.0.0
        .package(url: "https://github.com/kean/Pulse", revision: "a4e5bc2b0439552d4ff5fc9667c389be6ef5bd52"), // 5.2.2
    ],
    targets: [
        .macro(
            name: "CBPlaygroundLoggingMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "CBPlaygroundLogging",
            dependencies: [
                "CBPlaygroundLoggingMacros",
                .product(name: "Pulse", package: "Pulse"),
            ]
        ),
        .testTarget(
            name: "CBPlaygroundLoggingTests",
            dependencies: [
                "CBPlaygroundLoggingMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
