//
//  BLELogMacro.swift
//  CBPlaygroundMacrosPlugin
//

import SwiftSyntax
import SwiftSyntaxMacros

/// `@BLELog` の body マクロ実装。
///
/// 設計思想は「ログを取りすぎない／取らなすぎない」という規律を型の不自由さで強制することにある。
/// このマクロを付けたメソッドは、メソッドの脱出時（exit）にちょうど 1 行だけログを出す。途中経過の
/// ログは書けない。1 行で説明しきれないメソッドは責務過多のシグナルとみなす。
///
/// 既定は「結果捕捉版」であり、本文を do/catch で包んで成功・失敗と結末（戻り値）を 1 行に集約する。
/// async / throws / 戻り値あり・なし・Void のすべてのシグネチャで一貫した展開になるよう、元の本文を
/// 入れ子関数 `__blelogBody` へ退避し、その呼び出し結果を捕捉する方式を採る。入れ子関数は元の本文の
/// `return` をそのまま受け止められるため、本文を書き換えずに包める。
public enum BLELogMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard
            let function = declaration.as(FunctionDeclSyntax.self)
        else {
            // メソッド（関数宣言）以外への付与は意味を持たないため、診断を出して展開しない。
            context.diagnose(BLELogDiagnostic.notAFunction.at(node))
            return []
        }

        guard
            let originalBody = function.body
        else {
            // protocol 要件など本文を持たない宣言には適用できない。
            context.diagnose(BLELogDiagnostic.missingBody.at(node))
            return []
        }

        let arguments = BLELogArguments(from: node)
        let label = arguments.resolvedLabel(in: context)
        let message = arguments.message
        let level = arguments.level

        let signature = function.signature
        let effects = signature.effectSpecifiers
        let isAsync = effects?.asyncSpecifier != nil
        let throwsClause = throwsEffect(of: effects)
        let returnType = signature.returnClause?.type.trimmed
        let returnsValue = !isVoid(returnType)

        // 入れ子関数の呼び出し前置詞（try / await）を組み立てる。順序は `try await` で固定する。
        let callPrefix = buildCallPrefix(isThrowing: throwsClause.isThrowing, isAsync: isAsync)

        // 入れ子関数のシグネチャ。元の effect 指定子と戻り値型をそのまま引き継ぐ。
        let nestedEffects = buildNestedEffects(isAsync: isAsync, throwsClause: throwsClause)
        let nestedReturnClause = returnsValue ? " -> \(returnType!.description)" : ""

        let successMessage = makeSuccessMessage(message: message, returnsValue: returnsValue)
        let logCall = "BLELogRuntime.log(\"\(label)\", \"\(successMessage)\", level: \(level))"
        let failureCall = "BLELogRuntime.log(\"\(label)\", \"\(message) → 失敗(\\(error))\", level: .error)"

        // 元の本文を入れ子関数 `__blelogBody` へ退避する。文ごとに trivia を整え、予測可能な整形にする。
        let nestedBody = buildNestedFunction(
            statements: originalBody.statements,
            effects: nestedEffects,
            returnClause: nestedReturnClause
        )

        var statements: [CodeBlockItemSyntax]
        if throwsClause.isThrowing {
            // 失敗経路があるため do/catch で包み、成功・失敗の双方を 1 行ログにする。
            var doStatements: [CodeBlockItemSyntax] = nestedBody
            doStatements.append("let __blelogResult = \(raw: callPrefix)__blelogBody()")
            doStatements.append("\(raw: logCall)")
            if returnsValue {
                doStatements.append("return __blelogResult")
            }
            else {
                // Void では結末を返さないため return 文を足さない。
            }

            let doBlock = CodeBlockItemListSyntax(doStatements)
            statements = [
                """
                do {
                \(doBlock)
                }
                catch {
                \(raw: failureCall)
                throw error
                }
                """,
            ]
        }
        else {
            // 失敗経路が無いメソッドでも、成功 1 行ログという同じ規律を課す（一貫した展開）。
            statements = nestedBody
            statements.append("let __blelogResult = \(raw: callPrefix)__blelogBody()")
            statements.append("\(raw: logCall)")
            if returnsValue {
                statements.append("return __blelogResult")
            }
            else {
                // Void では結末を返さないため return 文を足さない。
            }
        }

        return statements
    }

    // MARK: 補助

    /// 元の本文を退避する入れ子関数 `__blelogBody` を 1 つの CodeBlockItem として組み立てる。
    /// 各文の前後の trivia を取り除いて改行で連結し、展開後の整形が予測可能になるようにする。
    private static func buildNestedFunction(
        statements: CodeBlockItemListSyntax,
        effects: String,
        returnClause: String
    ) -> [CodeBlockItemSyntax] {
        let normalizedBody = statements
            .map(\.trimmedDescription)
            .joined(separator: "\n")
        let function: CodeBlockItemSyntax = """
        func __blelogBody()\(raw: effects)\(raw: returnClause) {
        \(raw: normalizedBody)
        }
        """
        return [function]
    }

    /// 戻り値の有無で成功時メッセージの結末表記を切り替える。
    /// 戻り値があるメソッドは結果を `成功(<戻り値>)` として差し込み、Void は `成功` のみとする。
    private static func makeSuccessMessage(message: String, returnsValue: Bool) -> String {
        if returnsValue {
            "\(message) → 成功(\\(__blelogResult))"
        }
        else {
            // Void のメソッドは結末を持たないため、件数等を付けず「成功」だけを記録する。
            "\(message) → 成功"
        }
    }

    /// 入れ子関数を呼ぶ際の前置詞（`try await` など）を組み立てる。
    private static func buildCallPrefix(isThrowing: Bool, isAsync: Bool) -> String {
        var prefix = ""
        if isThrowing {
            prefix += "try "
        }
        else {
            // 非 throws では try を付けない。
        }
        if isAsync {
            prefix += "await "
        }
        else {
            // 非 async では await を付けない。
        }
        return prefix
    }

    /// 入れ子関数に付ける effect 指定子（` async throws` など）を組み立てる。
    private static func buildNestedEffects(isAsync: Bool, throwsClause: ThrowsEffect) -> String {
        var specifiers = ""
        if isAsync {
            specifiers += " async"
        }
        else {
            // 非 async では async を付けない。
        }
        if throwsClause.isThrowing {
            specifiers += " " + throwsClause.keyword
        }
        else {
            // 非 throws では throws を付けない。
        }
        return specifiers
    }

    /// 型が Void（戻り値なし）かどうかを判定する。戻り値節が無い場合と `Void` / `()` を Void とみなす。
    private static func isVoid(_ type: TypeSyntax?) -> Bool {
        guard
            let type
        else {
            return true
        }
        let text = type.trimmedDescription
        if text == "Void" || text == "()" {
            return true
        }
        else {
            return false
        }
    }

    /// throws 指定子を取り出す。`rethrows` も throws と同様に失敗経路ありとして扱う。
    private static func throwsEffect(of effects: FunctionEffectSpecifiersSyntax?) -> ThrowsEffect {
        guard
            let throwsSpecifier = effects?.throwsClause?.throwsSpecifier
        else {
            return ThrowsEffect(isThrowing: false, keyword: "")
        }
        return ThrowsEffect(isThrowing: true, keyword: throwsSpecifier.text)
    }
}

/// throws 指定子の有無と、その綴り（`throws` / `rethrows`）を表す。
private struct ThrowsEffect {
    let isThrowing: Bool
    let keyword: String
}
