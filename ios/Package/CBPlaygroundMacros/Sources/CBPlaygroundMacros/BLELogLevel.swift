//
//  BLELogLevel.swift
//  CBPlaygroundMacros
//

import Pulse

/// `@BLELog` で指定するログレベル。
///
/// 既存実装では絵文字接頭辞（🔍 ⏹ ↻ ✚ ⚠️ など）でログの種別を表していたが、これは表記が揺れやすく
/// 機械的なフィルタにも向かない。本マクロではレベル表示へ一本化し、絵文字接頭辞は廃止する。
/// 値は Pulse の `LoggerStore.Level` へ対応づける（`pulseLevel`）。
public enum BLELogLevel: Sendable {
    /// 詳細な追跡情報。通常運用では出さない粒度。
    case debug
    /// 正常系の節目を表す既定レベル。
    case info
    /// 異常ではないが注意を促す状況。
    case warning
    /// 失敗・エラー。throws の catch 経路は常にこのレベルで記録する。
    case error

    // MARK: Computed Properties

    /// Pulse の `LoggerStore.Level` への対応づけ。
    public var pulseLevel: LoggerStore.Level {
        switch self {
        case .debug:
            .debug
        case .info:
            .info
        case .warning:
            .warning
        case .error:
            .error
        }
    }
}
