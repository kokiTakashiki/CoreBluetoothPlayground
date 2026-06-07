//
//  DynamicBLELog.swift
//  CBPlaygroundLogging
//

/// 動的に payload を組み立てる body マクロ。`@BLELog` で表現できない場合に限り使う「切り札」。
///
/// `@BLELog` は `message: String` 固定文を前提とした「不自由なマクロ」であり、引数値ごとに本文を変える
/// 用途（例: `CBManagerState` の値ごとに「状態変化 unknown」「状態変化 poweredOn」のように分岐させたい
/// ケース）では破綻する。従来この壁は `private func record(_:) -> String` を `@discardableResult` で
/// 戻り値偽装し、`@BLELog` の結末ログに横流しすることで凌いでいたが、これは戻り値の意味を歪める smell で
/// あり `@BLELog` の規律と整合しない。
///
/// `@DynamicBLELog` は `source:` クロージャ内で `DynamicBLELogPayload` を返すことで、関数引数を
/// 仮引数として受け取りながら payload を組み立てる経路を提供する。マクロ展開時にクロージャは関数本文の
/// 末尾へ埋め込まれ、関数引数をそのまま渡して呼び出される。Swift は属性引数（attribute argument）の
/// クロージャを attribute スコープで型検査するため、関数引数や `self` をクロージャ本体から直接参照する
/// ことはできない（A 案＝字義スコープは Swift の言語仕様上成立しない）。本マクロは現実解として B 案を
/// 採用し、クロージャを `(関数引数の型...) -> DynamicBLELogPayload` の形にすることで、仮引数経由で
/// 関数引数を読めるようにしている。`async` / `throws` / 戻り値あり・なし・`Void` のすべてで `@BLELog`
/// と一貫した「結果捕捉版」の展開になる。
///
/// 失敗経路（throws の catch）では `source:` クロージャを評価する意味がないため、別経路として静的に
/// `failureMessage:` と `failureLabel:` を与える。`failureMessage` が未指定なら本文は `失敗(<error>)` の
/// 形となり、指定があれば `<failureMessage> → 失敗(<error>)` を `.error` レベルで記録する。`failureLabel`
/// の既定値 `"BLELog"` は、失敗時にどの label が一番目立つべきかが文脈依存であり、フォールバック値を
/// 一意に決められないため、診断容易性を優先して中立的なリテラルにしてある。本物の運用では呼び出し側が
/// 明示指定することを推奨する。
///
/// 戻り値ありメソッドに付けたとき、戻り値は `source:` クロージャからは見えない（クロージャは関数引数と
/// `self` だけをレキシカルに参照する）。これは将来要件としての保留事項であり、本マクロでは設計外。
///
/// **濫用厳禁:** 切り札は規律の例外であり、安易に使うと「1 メソッド = ログ 1 行」の不自由さが崩れる。
/// 適用判断は doc・意思決定ログ・PR レビューで抑える（マクロ自体は誤用を防げない）。原則は次のとおり。
/// - まず `@BLELog` で表現できないか試す
/// - 表現できないとき（引数値で本文を変えたい・Void で結末を語りたい）のみ `@DynamicBLELog` を使う
///
/// 使用例:
/// ```swift
/// @DynamicBLELog(source: { (central: CBCentralManager) in
///     switch central.state {
///     case .poweredOn:
///         return DynamicBLELogPayload(level: .info, message: "状態変化 poweredOn", label: "CBCentralManager")
///     // …
///     }
/// })
/// func centralManagerDidUpdateState(_ central: CBCentralManager) {
///     onChange?()
/// }
/// ```
@attached(body)
public macro DynamicBLELog<each Arg>(
    failureMessage: String? = nil,
    failureLabel: String = "BLELog",
    source: (repeat each Arg) -> DynamicBLELogPayload
) = #externalMacro(module: "CBPlaygroundLoggingMacros", type: "DynamicBLELogMacro")
