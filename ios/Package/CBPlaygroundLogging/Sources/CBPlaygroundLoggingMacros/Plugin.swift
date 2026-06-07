//
//  Plugin.swift
//  CBPlaygroundLoggingMacros
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// コンパイラへ提供するマクロ一覧を束ねるプラグインのエントリポイント。
@main
struct CBPlaygroundLoggingMacros: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        BLELogMacro.self,
    ]
}
