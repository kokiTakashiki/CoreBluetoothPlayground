//
//  Topic.swift
//  CoreBluetoothPlayground
//

/// 一覧メニューに並ぶ Core Bluetooth トピック（各クラス）の識別。
/// 表示名だけを持つ純粋なデータで、画面生成は持たない（生成は各 Router の責務）。
/// トピックを増やすときは case を足すだけでよく、遷移先の網羅は
/// `TopicListViewController.didSelectRowAt` の switch でコンパイラが強制する。
enum Topic: CaseIterable {

    case cbCentralManager

    // MARK: Computed Properties

    var title: String {
        switch self {
        case .cbCentralManager: "CBCentralManager"
        }
    }
}
