//
//  CBLogConsole.swift
//  CBPlaygroundConsole
//

import PulseUI
import SwiftUI
import UIKit

/// Pulse の ConsoleView を UIKit へホストして返す。app shell・各 Feature の「Logs」導線から使う。
@MainActor
public enum CBLogConsole {
    /// ログ閲覧画面を返す。
    /// - Parameter label: 将来的なラベル絞り込み用に受け取るが、ConsoleView の公開 API に
    ///   ラベル初期フィルタはないため現時点では全件表示する。
    public static func makeViewController(label: String? = nil) -> UIViewController {
        UIHostingController(rootView: ConsoleView())
    }
}
