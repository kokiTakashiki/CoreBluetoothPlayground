//
//  DynamicBLELogPayload.swift
//  CBPlaygroundLogging
//

/// `@DynamicBLELog` の `source:` クロージャが返すログ payload。
///
/// `@BLELog` は `message: String` の固定文を前提にした「不自由なマクロ」であり、引数値ごとにメッセージを
/// 切り替える用途では表現力が足りない。`@DynamicBLELog` は切り札として、メソッドの引数や `self` の
/// プロパティを参照しながら動的に payload を組み立てる経路を提供する。
///
/// 本型は `level` / `message` / `label` を一括で持つ値型であり、`@BLELog` の規約と一貫させるため
/// `BLELogRuntime.log(_:_:level:)` に橋渡しする際の入力となる。`Sendable` 準拠とし、クロージャ内で
/// 構築した payload をアクタ境界を越えて渡せるようにする。
public struct DynamicBLELogPayload: Sendable {

    // MARK: Properties

    /// ログレベル。`@BLELog` と同様に成功経路を表現する軸として用いる。
    public let level: BLELogLevel

    /// 動作と結末を 1 行で表す本文。動的に組み立てるため文字列補間を含んでよい。
    public let message: String

    /// ConsoleView のラベル絞り込みに用いる識別子。Core Bluetooth のインターフェース名
    /// （例: "CBCentralManager"）を入れる運用を想定する。
    public let label: String

    // MARK: Lifecycle

    public init(level: BLELogLevel, message: String, label: String) {
        self.level = level
        self.message = message
        self.label = label
    }
}
