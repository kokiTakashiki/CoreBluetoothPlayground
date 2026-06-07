//
//  BLELog.swift
//  CBPlaygroundLogging
//

/// メソッドの脱出時（exit）にちょうど 1 行だけログを出す body マクロ。
///
/// このマクロの狙いはボイラープレート削減ではなく、ログの取り方を規律で縛ることにある。ログは簡単に取れる
/// からこそ取りすぎ・取らなすぎが起きる。そこで「1 メソッド = ログ 1 行」を型の不自由さで強制する。途中経過の
/// ログは書けないため、1 行で説明しきれないメソッドは責務過多のシグナルとみなせる。
///
/// 展開は「結果捕捉版」を既定とする。本文を do/catch（throws のとき）で包み、成功・失敗と結末（戻り値）を
/// exit の 1 行に集約する。`async` / `throws` / 戻り値あり・なし・`Void` のすべてで一貫した展開になる。
///
/// メッセージ規約は次のとおり。`message` には動作を 1 行で表す固定文（補間なし）を渡す。展開時に末尾へ結末が
/// 自動付与される。
/// - 成功・戻り値あり: `<message> → 成功(<戻り値>)`
/// - 成功・戻り値なし（Void）: `<message> → 成功`
/// - 失敗（throws が送出）: `<message> → 失敗(<error>)`、レベルは常に `.error`
///
/// `label` を省略すると、囲っている型名（class / struct / enum / actor / extension の対象型）を自動採番する。
/// 明示指定も可能で、その場合は指定値をそのまま使う。`level` を省略すると `.info` を使う。
///
/// 使用例:
/// ```swift
/// @BLELog(level: .info, message: "サービス探索")
/// func discoverServices() async throws -> [CBService] { … }
/// ```
@attached(body)
public macro BLELog(
    level: BLELogLevel = .info,
    message: String,
    label: String? = nil
) = #externalMacro(module: "CBPlaygroundLoggingMacros", type: "BLELogMacro")
