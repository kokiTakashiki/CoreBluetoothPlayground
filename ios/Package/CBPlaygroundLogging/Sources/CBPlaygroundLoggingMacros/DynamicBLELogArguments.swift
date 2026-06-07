//
//  DynamicBLELogArguments.swift
//  CBPlaygroundLoggingMacros
//

import SwiftSyntax

/// `@DynamicBLELog(failureMessage:failureLabel:source:)` の属性引数を解釈した結果を保持する。
///
/// 引数の解釈方針は次のとおり。
/// - `failureMessage` は省略可能な文字列リテラル。throws 経路の catch 側で前置するメッセージ。
/// - `failureLabel` は省略可能で、省略時は `"BLELog"`。失敗時は `source:` クロージャを評価できない
///   ため、別経路として静的に label を与える。
/// - `source` はクロージャ式（`{ … }`）が必須。マクロ展開時に本文末尾へ inline 展開して、関数引数と
///   `self` をレキシカルに見せる（A 案＝字義スコープ）。
struct DynamicBLELogArguments {

    // MARK: Properties

    /// 失敗時のメッセージ本文。未指定なら nil とし、展開側で「失敗(<error>)」のみのフォーマットに切り替える。
    let failureMessage: String?

    /// 失敗時に使う label。明示指定がなければ `"BLELog"` のフォールバック値を採用する。
    let failureLabel: String

    /// `source:` クロージャ式そのもの。マクロ展開時に式ごと埋め込み、関数引数を渡して呼び出す。
    /// クロージャ式が指定されていない場合は nil（診断対象）。
    let sourceClosure: ClosureExprSyntax?

    // MARK: Lifecycle

    init(from node: AttributeSyntax) {
        var parsedFailureMessage: String?
        var parsedFailureLabel = "BLELog"
        var parsedSourceClosure: ClosureExprSyntax?

        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                let name = argument.label?.text
                if name == "failureMessage" {
                    parsedFailureMessage = Self.stringLiteralValue(of: argument.expression)
                }
                else if name == "failureLabel" {
                    parsedFailureLabel = Self.stringLiteralValue(of: argument.expression) ?? parsedFailureLabel
                }
                else if name == "source" {
                    parsedSourceClosure = argument.expression.as(ClosureExprSyntax.self)
                }
                else {
                    // 想定外のラベルは無視する（マクロ宣言のシグネチャ側で弾かれる）。
                }
            }
        }
        else {
            // 引数なしの付与は `source:` 欠落として展開側の診断に委ねる。
        }

        failureMessage = parsedFailureMessage
        failureLabel = parsedFailureLabel
        sourceClosure = parsedSourceClosure
    }

    // MARK: Static Functions

    // MARK: Private

    /// 文字列リテラル式から、セグメントを連結した素の文字列値を取り出す。
    /// 文字列補間を含む式は対象外（nil）とし、`failureMessage` などは純粋なリテラルだけを許す。
    private static func stringLiteralValue(of expression: ExprSyntax) -> String? {
        guard
            let literal = expression.as(StringLiteralExprSyntax.self)
        else {
            return nil
        }
        var value = ""
        for segment in literal.segments {
            if let stringSegment = segment.as(StringSegmentSyntax.self) {
                value += stringSegment.content.text
            }
            else {
                // 補間セグメントは静的ラベル文に許さない（取りすぎ防止のため固定文に限る）。
                return nil
            }
        }
        return value
    }

}
