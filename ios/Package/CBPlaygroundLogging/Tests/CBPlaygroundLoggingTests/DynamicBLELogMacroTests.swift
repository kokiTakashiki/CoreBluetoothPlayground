//
//  DynamicBLELogMacroTests.swift
//  CBPlaygroundLoggingTests
//

import CBPlaygroundLoggingMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

/// `@DynamicBLELog` の展開を各シグネチャパターンで検証する。
///
/// `@BLELog` と同じ「結果捕捉版」展開を踏襲しつつ、`source:` クロージャは関数引数を仮引数として受け取る形
/// （B 案）で実装する。Swift は属性引数のクロージャを attribute スコープで型検査するため字義スコープの
/// A 案は成立しない。マクロ展開時にクロージャは関数本文末尾で関数引数を渡して呼び出される。失敗経路では
/// クロージャを評価できないため、別経路の静的 `failureMessage` / `failureLabel` を使う展開になる。
final class DynamicBLELogMacroTests: XCTestCase {

    // MARK: Properties

    private let macros: [String: Macro.Type] = [
        "DynamicBLELog": DynamicBLELogMacro.self,
    ]

    // MARK: Functions

    // MARK: 非 throws・Void・引数 1 個（仮引数経由で関数引数を参照する）

    func testVoidNonThrowingWithArgumentReference() {
        assertMacroExpansion(
            """
            struct Sample {
                @DynamicBLELog(source: { (state: State) in
                    switch state {
                    case .on:
                        return DynamicBLELogPayload(level: .info, message: "状態 on", label: "Sample")
                    case .off:
                        return DynamicBLELogPayload(level: .info, message: "状態 off", label: "Sample")
                    }
                })
                func handle(_ state: State) {
                    onChange?()
                }
            }
            """,
            expandedSource: """
            struct Sample {
                func handle(_ state: State) {
                    func __blelogBody() {
                        onChange?()
                    }
                    __blelogBody()
                    let __dynamicBLELogPayload: DynamicBLELogPayload = ({ (state: State) in
                            switch state {
                            case .on:
                                return DynamicBLELogPayload(level: .info, message: "状態 on", label: "Sample")
                            case .off:
                                return DynamicBLELogPayload(level: .info, message: "状態 off", label: "Sample")
                            }
                        })(state)
                    BLELogRuntime.log(__dynamicBLELogPayload.label, __dynamicBLELogPayload.message, level: __dynamicBLELogPayload.level)
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: 非 throws・Void・引数なし（クロージャは引数なしで呼ばれる）

    func testVoidNonThrowingNoArguments() {
        assertMacroExpansion(
            """
            struct Sample {
                @DynamicBLELog(source: { () in
                    return DynamicBLELogPayload(level: .info, message: "tick", label: "Sample")
                })
                func tick() {
                    bump()
                }
            }
            """,
            expandedSource: """
            struct Sample {
                func tick() {
                    func __blelogBody() {
                        bump()
                    }
                    __blelogBody()
                    let __dynamicBLELogPayload: DynamicBLELogPayload = ({ () in
                            return DynamicBLELogPayload(level: .info, message: "tick", label: "Sample")
                        })()
                    BLELogRuntime.log(__dynamicBLELogPayload.label, __dynamicBLELogPayload.message, level: __dynamicBLELogPayload.level)
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: throws・Void・failureMessage 指定あり（catch で `<failureMessage> → 失敗(<error>)`）

    func testThrowingVoidWithFailureMessage() {
        assertMacroExpansion(
            """
            struct Sample {
                @DynamicBLELog(failureMessage: "サービス探索", failureLabel: "CBPeripheral", source: { () in
                    return DynamicBLELogPayload(level: .info, message: "成功", label: "CBPeripheral")
                })
                func discover() throws {
                    try load()
                }
            }
            """,
            expandedSource: """
            struct Sample {
                func discover() throws {
                    do {
                        func __blelogBody() throws {
                            try load()
                        }
                        try __blelogBody()
                        let __dynamicBLELogPayload: DynamicBLELogPayload = ({ () in
                                return DynamicBLELogPayload(level: .info, message: "成功", label: "CBPeripheral")
                            })()
                        BLELogRuntime.log(__dynamicBLELogPayload.label, __dynamicBLELogPayload.message, level: __dynamicBLELogPayload.level)
                    }
                    catch {
                        BLELogRuntime.log("CBPeripheral", "サービス探索 → 失敗(\\(error))", level: .error)
                        throw error
                    }
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: throws・Void・failureMessage 未指定（catch で `失敗(<error>)` のみ、failureLabel 既定値）

    func testThrowingVoidWithoutFailureMessage() {
        assertMacroExpansion(
            """
            struct Sample {
                @DynamicBLELog(source: { () in
                    return DynamicBLELogPayload(level: .info, message: "成功", label: "Sample")
                })
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
                        try __blelogBody()
                        let __dynamicBLELogPayload: DynamicBLELogPayload = ({ () in
                                return DynamicBLELogPayload(level: .info, message: "成功", label: "Sample")
                            })()
                        BLELogRuntime.log(__dynamicBLELogPayload.label, __dynamicBLELogPayload.message, level: __dynamicBLELogPayload.level)
                    }
                    catch {
                        BLELogRuntime.log("BLELog", "失敗(\\(error))", level: .error)
                        throw error
                    }
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: async・Void（success クロージャ呼び出し前置に await が付く）

    func testAsyncVoid() {
        assertMacroExpansion(
            """
            struct Sample {
                @DynamicBLELog(source: { () in
                    return DynamicBLELogPayload(level: .info, message: "待機完了", label: "Sample")
                })
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
                    await __blelogBody()
                    let __dynamicBLELogPayload: DynamicBLELogPayload = ({ () in
                            return DynamicBLELogPayload(level: .info, message: "待機完了", label: "Sample")
                        })()
                    BLELogRuntime.log(__dynamicBLELogPayload.label, __dynamicBLELogPayload.message, level: __dynamicBLELogPayload.level)
                }
            }
            """,
            macros: macros
        )
    }

    // MARK: 戻り値あり・非 throws（クロージャから戻り値は見えない・関数引数のみ）

    func testReturningValueNonThrowing() {
        assertMacroExpansion(
            """
            struct Sample {
                @DynamicBLELog(source: { () in
                    return DynamicBLELogPayload(level: .info, message: "件数取得", label: "Sample")
                })
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
                    let __dynamicBLELogPayload: DynamicBLELogPayload = ({ () in
                            return DynamicBLELogPayload(level: .info, message: "件数取得", label: "Sample")
                        })()
                    BLELogRuntime.log(__dynamicBLELogPayload.label, __dynamicBLELogPayload.message, level: __dynamicBLELogPayload.level)
                    return __blelogResult
                }
            }
            """,
            macros: macros
        )
    }
}
