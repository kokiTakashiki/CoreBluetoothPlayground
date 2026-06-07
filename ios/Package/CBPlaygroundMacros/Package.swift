// swift-tools-version: 6.0
import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "CBPlaygroundMacros",
    defaultLocalization: "ja",
    platforms: [.iOS("26.0"), .macOS("13.0")],
    products: [
        // マクロを利用側へ公開するライブラリ。`@BLELog` の宣言と、Pulse へ書き込むランタイム facade を含む。
        .library(name: "CBPlaygroundMacros", targets: ["CBPlaygroundMacros"]),
    ],
    dependencies: [
        // サプライチェーン対策でタグではなくコミット SHA で固定する（D-008 と同方針）。
        // swift-syntax 602.0.0 は Swift 6.1 以降のツールチェーンと両立する最新安定リリース。
        .package(
            url: "https://github.com/swiftlang/swift-syntax",
            revision: "4799286537280063c85a32f09884cfbca301b1a1"
        ), // 602.0.0
        // ログ書き込みは Pulse の LoggerStore を使う（CBPlaygroundCore と同一 SHA で固定）。
        .package(url: "https://github.com/kean/Pulse", revision: "a4e5bc2b0439552d4ff5fc9667c389be6ef5bd52"), // 5.2.2
    ],
    targets: [
        // マクロ実装本体（コンパイラプラグイン）。ビルドホスト（macOS）上で動く。
        .macro(
            name: "CBPlaygroundMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        // 利用側が import するライブラリ。マクロ宣言とランタイム facade `BLELogRuntime` を公開する。
        .target(
            name: "CBPlaygroundMacros",
            dependencies: [
                "CBPlaygroundMacrosPlugin",
                .product(name: "Pulse", package: "Pulse"),
            ]
        ),
        // マクロ展開のユニットテスト。各シグネチャパターンの展開を文字列比較で検証する。
        .testTarget(
            name: "CBPlaygroundMacrosTests",
            dependencies: [
                "CBPlaygroundMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
