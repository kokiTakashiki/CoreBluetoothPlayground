//
//  Plugin.swift
//  CBPlaygroundMacrosPlugin
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// コンパイラへ提供するマクロ一覧を束ねるプラグインのエントリポイント。
@main
struct CBPlaygroundMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        BLELogMacro.self,
    ]
}
