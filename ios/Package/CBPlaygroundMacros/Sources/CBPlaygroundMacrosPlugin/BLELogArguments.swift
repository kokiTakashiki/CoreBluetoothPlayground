//
//  BLELogArguments.swift
//  CBPlaygroundMacrosPlugin
//

import SwiftSyntax
import SwiftSyntaxMacros

/// `@BLELog(level:message:label:)` の属性引数を解釈した結果を保持する。
///
/// 引数の解釈方針は次のとおり。
/// - `message` は必須の文字列リテラル。メソッドが何をするのかを 1 行で表すラベル文。
/// - `level` は省略可能で、省略時は `.info`。`BLELogLevel` の case をそのまま展開コードへ埋め込む。
/// - `label` は省略可能で、省略時は囲っている型名から自動採番する（`resolvedLabel(in:)`）。
struct BLELogArguments {

    // MARK: Properties

    /// メソッドの動作を 1 行で説明するメッセージ。展開コードへ文字列として埋め込む。
    let message: String

    /// ログレベル。`.info` のように先頭ドット付きの式文字列として保持する。
    let level: String

    /// 明示指定された label。未指定なら nil とし、`resolvedLabel(in:)` で型名から補う。
    private let explicitLabel: String?

    // MARK: Lifecycle

    init(from node: AttributeSyntax) {
        var parsedMessage = ""
        var parsedLevel = ".info"
        var parsedLabel: String?

        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                let name = argument.label?.text
                if name == "message" {
                    parsedMessage = Self.stringLiteralValue(of: argument.expression) ?? ""
                }
                else if name == "level" {
                    parsedLevel = argument.expression.trimmedDescription
                }
                else if name == "label" {
                    parsedLabel = Self.stringLiteralValue(of: argument.expression)
                }
                else {
                    // 想定外のラベルは無視する（マクロ宣言のシグネチャ側で弾かれる）。
                }
            }
        }
        else {
            // 引数なしの付与は message 欠落としてそのまま空文字で進み、宣言シグネチャ側のエラーに委ねる。
        }

        message = parsedMessage
        level = parsedLevel
        explicitLabel = parsedLabel
    }

    // MARK: Static Functions

    // MARK: Private

    /// 文字列リテラル式から、セグメントを連結した素の文字列値を取り出す。
    /// 文字列補間を含む式は対象外（nil）とし、ラベル文は純粋なリテラルだけを許す。
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
                // 補間セグメントはラベル文に許さない（取りすぎ防止のため固定文に限る）。
                return nil
            }
        }
        return value
    }

    /// 囲っている型名を lexicalContext から辿って取り出す。
    ///
    /// body マクロの `context.lexicalContext` には、付与されたメソッドを内側から外側へ包む宣言が
    /// 並ぶ。最も内側の型宣言（class / struct / enum / actor / extension）を 1 つ見つけて、その名前を
    /// label とする。extension の場合は拡張対象の型名を使う。
    private static func enclosingTypeName(in context: some MacroExpansionContext) -> String? {
        for syntax in context.lexicalContext {
            if let classDecl = syntax.as(ClassDeclSyntax.self) {
                return classDecl.name.text
            }
            else if let structDecl = syntax.as(StructDeclSyntax.self) {
                return structDecl.name.text
            }
            else if let enumDecl = syntax.as(EnumDeclSyntax.self) {
                return enumDecl.name.text
            }
            else if let actorDecl = syntax.as(ActorDeclSyntax.self) {
                return actorDecl.name.text
            }
            else if let extensionDecl = syntax.as(ExtensionDeclSyntax.self) {
                return extensionDecl.extendedType.trimmedDescription
            }
            else {
                // 型宣言以外（関数など）は読み飛ばし、さらに外側を探す。
                continue
            }
        }
        return nil
    }

    // MARK: Functions

    // MARK: Internal

    /// 最終的に使う label を決める。明示指定があればそれを、無ければ囲っている型名を採番する。
    func resolvedLabel(in context: some MacroExpansionContext) -> String {
        if let explicitLabel {
            explicitLabel
        }
        else {
            Self.enclosingTypeName(in: context) ?? "BLELog"
        }
    }

}
