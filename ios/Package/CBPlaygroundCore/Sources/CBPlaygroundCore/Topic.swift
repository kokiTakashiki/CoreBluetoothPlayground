//
//  Topic.swift
//  CBPlaygroundCore
//

import UIKit

/// 一覧メニューに並ぶ 1 トピック（Core Bluetooth の 1 クラス）の最小契約。
/// 各機能モジュール（Router）がこれに準拠し、表示名と画面の生成口を提供する。
/// app shell はメニューに並べる `Topic.Type` の配列を持つだけでよい。
@MainActor
public protocol Topic {

    /// メニューに表示する Core Bluetooth クラス名（例: "CBCentralManager"）。
    static var title: String { get }

    /// 当該トピックの専用画面を生成して返す。
    static func makeViewController() -> UIViewController
}
