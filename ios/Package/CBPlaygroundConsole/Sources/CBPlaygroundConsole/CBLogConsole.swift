//
//  CBLogConsole.swift
//  CBPlaygroundConsole
//

import PulseUI
import SwiftUI
import UIKit

/// Pulse の ConsoleView を UIKit へホストして返す。app shell・各 Feature の「Logs」導線から使う。
/// 全ログを表示し、インターフェース別の絞り込みは ConsoleView の Filters（Labels）で行う
/// （各ログには `BLELog` が label を付与している）。ConsoleView の公開 API に初期ラベルフィルタが
/// 無いため、初期フィルタ引数は設けない。
@MainActor
public enum CBLogConsole {
    /// ログ閲覧画面を返す。
    public static func makeViewController() -> UIViewController {
        UIHostingController(rootView: ConsoleView())
    }
}
