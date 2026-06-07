//
//  DynamicBLELogMacro.swift
//  CBPlaygroundLoggingMacros
//

import SwiftSyntax
import SwiftSyntaxMacros

/// `@DynamicBLELog` の body マクロ実装。
///
/// `@BLELog` が固定文（`message: String`）を前提にする「不自由なマクロ」だったのに対し、本マクロは
/// `source:` クロージャ内で動的に `DynamicBLELogPayload` を組み立てる経路を提供する。Swift は属性引数
/// （attribute argument）のクロージャを attribute スコープで型検査するため、関数引数や `self` を
/// クロージャ本体から直接参照することはできない（A 案＝字義スコープ は Swift の言語仕様上成立しない）。
/// 本マクロは現実解として B 案を採用し、クロージャに関数引数を仮引数として受け取らせ、マクロ展開時に
/// 関数引数を渡して呼び出すことで、仮引数経由で関数引数を読めるようにする。
///
/// 展開は `@BLELog` と同じ「結果捕捉版」を踏襲する。元の本文を入れ子関数 `__blelogBody` へ退避し、
/// その呼び出し結果を捕捉して payload クロージャを呼んで `BLELogRuntime.log(...)` を 1 行呼ぶ。
/// `throws` のときは do/catch で包み、catch 側では `source:` を評価できないため別経路の静的
/// `failureMessage` / `failureLabel` を使う。
public enum DynamicBLELogMacro: BodyMacro {
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

        let arguments = DynamicBLELogArguments(from: node)
        guard
            let sourceClosure = arguments.sourceClosure
        else {
            // `source:` クロージャが無い・クロージャ式でない場合は意味を持たない。
            context.diagnose(BLELogDiagnostic.missingSource.at(node))
            return []
        }

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

        // 元の本文を入れ子関数 `__blelogBody` へ退避する。文ごとに trivia を整え、予測可能な整形にする。
        let nestedBody = buildNestedFunction(
            statements: originalBody.statements,
            effects: nestedEffects,
            returnClause: nestedReturnClause
        )

        // payload クロージャは属性スコープに置かれるため、関数引数や `self` を直接参照できない。そこで
        // クロージャは関数引数を仮引数として受け取り、マクロ展開時に関数引数を渡して呼び出す。これにより
        // クロージャ本体は仮引数を介して関数引数を読める（B 案の現実解）。
        let argumentForwarding = forwardingArgumentList(of: signature.parameterClause.parameters)
        let normalizedClosure = sourceClosure.trimmedDescription
        let payloadEvaluation: CodeBlockItemSyntax = """
        let __dynamicBLELogPayload: DynamicBLELogPayload = (\(raw: normalizedClosure))(\(raw: argumentForwarding))
        """
        let successLogCall: CodeBlockItemSyntax = """
        BLELogRuntime.log(__dynamicBLELogPayload.label, __dynamicBLELogPayload.message, level: __dynamicBLELogPayload.level)
        """

        let failureCall = buildFailureCall(
            failureMessage: arguments.failureMessage,
            failureLabel: arguments.failureLabel
        )

        var statements: [CodeBlockItemSyntax]
        if throwsClause.isThrowing {
            // 失敗経路があるため do/catch で包み、成功・失敗の双方を 1 行ログにする。
            // 成功側は payload クロージャを評価して動的に message を決め、失敗側は別経路の静的指定を使う。
            var doStatements: [CodeBlockItemSyntax] = nestedBody
            if returnsValue {
                doStatements.append("let __blelogResult = \(raw: callPrefix)__blelogBody()")
            }
            else {
                // Void では結果を保持しない。
                doStatements.append("\(raw: callPrefix)__blelogBody()")
            }
            doStatements.append(payloadEvaluation)
            doStatements.append(successLogCall)
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
            if returnsValue {
                statements.append("let __blelogResult = \(raw: callPrefix)__blelogBody()")
            }
            else {
                // Void では結果を保持しない。
                statements.append("\(raw: callPrefix)__blelogBody()")
            }
            statements.append(payloadEvaluation)
            statements.append(successLogCall)
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

    /// 関数の仮引数を `source:` クロージャ呼び出し用の引数列へ変換する。各仮引数の内部名（`secondName`
    /// がある場合はそれ、無ければ `firstName`）をそのまま使う。`_` のように内部名が無い引数は呼び出し時に
    /// 使えないため、ここでは内部名（あるいは外部名）を選ぶ。Swift は `_ param` の `param` を内部名とし、
    /// `external param` の `param` を内部名とするので、`secondName ?? firstName` のフォールバックで網羅できる。
    private static func forwardingArgumentList(of parameters: FunctionParameterListSyntax) -> String {
        var parts: [String] = []
        for parameter in parameters {
            let internalName: TokenSyntax = if let secondName = parameter.secondName {
                secondName
            }
            else {
                // 外部名と内部名が同一のときは `firstName` のみが存在する。
                parameter.firstName
            }
            parts.append(internalName.text)
        }
        return parts.joined(separator: ", ")
    }

    /// catch 側で呼び出す失敗ログ文を組み立てる。`failureMessage` が未指定なら `失敗(<error>)` のみ、
    /// 指定があれば `<failureMessage> → 失敗(<error>)` を連結する。
    private static func buildFailureCall(failureMessage: String?, failureLabel: String) -> String {
        let body = if let failureMessage {
            "\(failureMessage) → 失敗(\\(error))"
        }
        else {
            // 失敗本文の前置が無い場合は結末だけを記録する。
            "失敗(\\(error))"
        }
        return "BLELogRuntime.log(\"\(failureLabel)\", \"\(body)\", level: .error)"
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
