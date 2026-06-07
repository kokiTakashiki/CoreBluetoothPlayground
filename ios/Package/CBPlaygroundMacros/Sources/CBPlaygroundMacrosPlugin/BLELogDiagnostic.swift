//
//  BLELogDiagnostic.swift
//  CBPlaygroundMacrosPlugin
//

import SwiftDiagnostics
import SwiftSyntax

/// `@BLELog` の誤用に対して出す診断メッセージ。
/// メソッド以外への付与や本文を持たない宣言への付与をコンパイル時に弾く。
enum BLELogDiagnostic: String, DiagnosticMessage {
    case notAFunction
    case missingBody

    // MARK: Computed Properties

    var message: String {
        switch self {
        case .notAFunction:
            "@BLELog はメソッド（関数宣言）にのみ付与できます。"
        case .missingBody:
            "@BLELog は本文を持つメソッドにのみ付与できます（protocol 要件などには付与できません）。"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "CBPlaygroundMacros", id: rawValue)
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
