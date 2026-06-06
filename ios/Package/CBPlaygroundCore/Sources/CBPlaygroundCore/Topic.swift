//
//  Topic.swift
//  CBPlaygroundCore
//

import UIKit

/// 一覧メニューに並ぶ 1 トピック（Core Bluetooth の 1 クラス）を表す値。
/// 表示名と画面の生成口（ファクトリ）を持つだけのデータで、振る舞いの多態は無いため struct とする。
/// app shell や各 Feature はこの値の配列を組み立ててメニューに並べる。
@MainActor
public struct Topic {

    // MARK: Properties

    /// メニューに表示する Core Bluetooth クラス名（例: "CBCentralManager"）。
    public let title: String

    /// 当該トピックの専用画面を生成して返すファクトリ。
    public let makeViewController: @MainActor () -> UIViewController

    // MARK: Lifecycle

    public init(title: String, makeViewController: @escaping @MainActor () -> UIViewController) {
        self.title = title
        self.makeViewController = makeViewController
    }
}
