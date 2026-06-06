//
//  InterfaceModule.swift
//  CBPlaygroundCore
//

import UIKit

/// インターフェース一覧メニューに並ぶ 1 モジュールの最小契約。
/// 各機能モジュール（Router）がこれに準拠し、メニュー表示名と画面の生成口を提供する。
/// app shell はメニューに並べる `InterfaceModule.Type` の配列を持つだけでよい。
@MainActor
public protocol InterfaceModule {

    /// メニューに表示する Core Bluetooth インターフェース名（例: "CBCentralManager"）。
    static var symbol: String { get }

    /// 当該インターフェースの専用画面を生成して返す。
    static func makeViewController() -> UIViewController
}
