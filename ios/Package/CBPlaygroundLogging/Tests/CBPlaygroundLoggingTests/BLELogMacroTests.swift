//
//  BLELogMacroTests.swift
//  CBPlaygroundLoggingTests
//

import CBPlaygroundLoggingMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

/// `@BLELog` の展開を各シグネチャパターンで検証する。
///
/// 検証はマクロ実装プラグインを直接読み込んで行う（ホスト macOS 上で展開する）。各テストは
/// 「結果捕捉版」の展開形が async / throws / 戻り値あり・なし・Void のすべてで一貫していることを確かめる。
final class BLELogMacroTests: XCTestCase {

    // MARK: Properties

    private let macros: [String: Macro.Type] = [
        "BLELog": BLELogMacro.self,
    ]

    // MARK: Functions

    // MARK: 戻り値なし・非 throws・非 async（Void の最小形）

    func testVoidNonThrowingNonAsync() {
        assertMacroExpansion(
            """
            struct Sample {
                @BLELog(message: "停止")
                func stop() {
                    doWork()
                }
            }
            """,
            expandedSource: """
            struct Sample {
                func stop() {
                    func __blelogBody() {
                        doWork()
                    }
                    let __blelogResult = __blelogBody()
                    BLELogRuntime.log("Sample", "停止 → 成功", level: .info)
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: 戻り値あり・非 throws（成功に戻り値を差し込む）

    func testReturningValueNonThrowing() {
        assertMacroExpansion(
            """
            struct Sample {
                @BLELog(level: .debug, message: "件数取得")
                func count() -> Int {
                    return items.count
                }
            }
            """,
            expandedSource: """
            struct Sample {
                func count() -> Int {
                    func __blelogBody() -> Int {
                        return items.count
                    }
                    let __blelogResult = __blelogBody()
                    BLELogRuntime.log("Sample", "件数取得 → 成功(\\(__blelogResult))", level: .debug)
                    return __blelogResult
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: throws・戻り値あり（do/catch で成功・失敗の双方を 1 行に）

    func testThrowingReturningValue() {
        assertMacroExpansion(
            """
            struct Sample {
                @BLELog(message: "サービス探索")
                func discover() throws -> [Int] {
                    return try load()
                }
            }
            """,
            expandedSource: """
            struct Sample {
                func discover() throws -> [Int] {
                    do {
                        func __blelogBody() throws -> [Int] {
                            return try load()
                        }
                        let __blelogResult = try __blelogBody()
                        BLELogRuntime.log("Sample", "サービス探索 → 成功(\\(__blelogResult))", level: .info)
                        return __blelogResult
                    }
                    catch {
                        BLELogRuntime.log("Sample", "サービス探索 → 失敗(\\(error))", level: .error)
                        throw error
                    }
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: async throws・戻り値あり（try await を一貫付与）

    func testAsyncThrowingReturningValue() {
        assertMacroExpansion(
            """
            struct Sample {
                @BLELog(level: .info, message: "接続")
                func connect() async throws -> Bool {
                    return try await session.open()
                }
            }
            """,
            expandedSource: """
            struct Sample {
                func connect() async throws -> Bool {
                    do {
                        func __blelogBody() async throws -> Bool {
                            return try await session.open()
                        }
                        let __blelogResult = try await __blelogBody()
                        BLELogRuntime.log("Sample", "接続 → 成功(\\(__blelogResult))", level: .info)
                        return __blelogResult
                    }
                    catch {
                        BLELogRuntime.log("Sample", "接続 → 失敗(\\(error))", level: .error)
                        throw error
                    }
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: async・戻り値なし（await のみ、Void）

    func testAsyncVoid() {
        assertMacroExpansion(
            """
            struct Sample {
                @BLELog(message: "待機")
                func wait() async {
                    await clock.tick()
                }
            }
            """,
            expandedSource: """
            struct Sample {
                func wait() async {
                    func __blelogBody() async {
                        await clock.tick()
                    }
                    let __blelogResult = await __blelogBody()
                    BLELogRuntime.log("Sample", "待機 → 成功", level: .info)
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: throws・戻り値なし（do/catch、Void）

    func testThrowingVoid() {
        assertMacroExpansion(
            """
            struct Sample {
                @BLELog(message: "保存")
                func save() throws {
                    try store.write()
                }
            }
            """,
            expandedSource: """
            struct Sample {
                func save() throws {
                    do {
                        func __blelogBody() throws {
                            try store.write()
                        }
                        let __blelogResult = try __blelogBody()
                        BLELogRuntime.log("Sample", "保存 → 成功", level: .info)
                    }
                    catch {
                        BLELogRuntime.log("Sample", "保存 → 失敗(\\(error))", level: .error)
                        throw error
                    }
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: label 明示指定（型名の自動採番より優先する）

    func testExplicitLabelOverridesTypeName() {
        assertMacroExpansion(
            """
            struct Sample {
                @BLELog(message: "停止", label: "CBCentralManager")
                func stop() {
                    doWork()
                }
            }
            """,
            expandedSource: """
            struct Sample {
                func stop() {
                    func __blelogBody() {
                        doWork()
                    }
                    let __blelogResult = __blelogBody()
                    BLELogRuntime.log("CBCentralManager", "停止 → 成功", level: .info)
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: extension 内（拡張対象の型名を採番する）

    func testLabelFromExtensionExtendedType() {
        assertMacroExpansion(
            """
            extension CBCentralScanInteractor {
                @BLELog(message: "スキャン停止")
                func stopScan() {
                    centralManager.stopScan()
                }
            }
            """,
            expandedSource: """
            extension CBCentralScanInteractor {
                func stopScan() {
                    func __blelogBody() {
                        centralManager.stopScan()
                    }
                    let __blelogResult = __blelogBody()
                    BLELogRuntime.log("CBCentralScanInteractor", "スキャン停止 → 成功", level: .info)
                }
            }
            """,
            macros: macros
        )
    }
}
