//
//  CBCentralManagerError.swift
//  CentralsFeature
//

import CoreBluetooth
import Foundation

/// CBCentralManager 系の操作が前提条件を満たせず失敗したときに投げるエラー。
///
/// 設計思想として、前提条件のあるメソッドは Void で受けず、違反は throws で押し出す。
/// Void + guard + silent return では呼び出し側から関数が走ったか走らなかったか区別できないため、
/// このエラー型で契約を型として明示し、View 側にも失敗を伝えてユーザーへ通知できる形にする。
public enum CBCentralManagerError: Error, LocalizedError {

    /// CBCentralManager の state が .poweredOn でないため操作できない。
    /// 現在の state を同梱して、呼び出し側がエラー文面に文脈を残せるようにする。
    case notPoweredOn(CBManagerState)

    /// stopScan が呼ばれたが、そもそもスキャン中ではなかった。
    case notScanning

    // MARK: Computed Properties

    public var errorDescription: String? {
        switch self {
        case let .notPoweredOn(state):
            stateDescription(for: state)
        case .notScanning:
            "スキャン中ではありません"
        }
    }

    // MARK: Functions

    /// CBManagerState を人間可読な説明文へ変換する。
    /// 旧 CBCentralScanInteractor 側に重複していた変換ロジックを DRY のためにここへ移植した。
    private func stateDescription(for state: CBManagerState) -> String {
        switch state {
        case .poweredOff:
            "Bluetooth がオフです"
        case .unauthorized:
            "Bluetooth の使用が許可されていません"
        case .unsupported:
            "Bluetooth Low Energy がサポートされていません"
        case .resetting:
            "Bluetooth をリセット中です"
        case .unknown:
            "Bluetooth の状態が不明です"
        default:
            "Bluetooth が利用できません (state=\(state.rawValue))"
        }
    }
}
