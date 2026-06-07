//
//  BLELogRuntime.swift
//  CBPlaygroundMacros
//

import Pulse

/// `@BLELog` の展開コードから呼ばれるランタイム facade。
///
/// マクロが生成する本文は `BLELogRuntime.log(_:_:level:)` を 1 回だけ呼ぶ。実体は Pulse の
/// `LoggerStore` へ書き込む薄い橋渡しで、`label` にインターフェース名（例 "CBCentralManager"）を入れて
/// ConsoleView でラベル絞り込みできるようにする。`BLELogLevel` を Pulse のレベルへマッピングして渡す。
///
/// 利用側がランタイムを直接呼ぶことは想定していない（ログ取得は `@BLELog` 経由に統一する）。
public enum BLELogRuntime {
    public static func log(_ label: String, _ message: String, level: BLELogLevel) {
        LoggerStore.shared.storeMessage(label: label, level: level.pulseLevel, message: message)
    }
}
