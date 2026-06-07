//
//  BLELogDiagnostic.swift
//  CBPlaygroundLoggingMacros
//

import SwiftDiagnostics
import SwiftSyntax

/// `@BLELog` / `@DynamicBLELog` の誤用に対して出す診断メッセージ。
/// メソッド以外への付与や本文を持たない宣言への付与をコンパイル時に弾く。
/// `@DynamicBLELog` 固有の診断として `source:` クロージャの欠落も扱う。
enum BLELogDiagnostic: String, DiagnosticMessage {
    case notAFunction
    case missingBody
    case missingSource

    // MARK: Computed Properties

    var message: String {
        switch self {
        case .notAFunction:
            "@BLELog はメソッド（関数宣言）にのみ付与できます。"
        case .missingBody:
            "@BLELog は本文を持つメソッドにのみ付与できます（protocol 要件などには付与できません）。"
        case .missingSource:
            "@DynamicBLELog には `source:` 引数（() -> DynamicBLELogPayload のクロージャ式）が必要です。"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "CBPlaygroundLogging", id: rawValue)
    }

    var severity: DiagnosticSeverity {
        .error
    }

    // MARK: Functions

    /// 指定したノードの位置にこの診断を結びつける。
    func at(_ node: some SyntaxProtocol) -> Diagnostic {
        Diagnostic(node: node, message: self)
    }
}
