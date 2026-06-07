//
//  CBCentralManagerInteractorInput.swift
//  CentralsFeature
//

import CBPlaygroundCore
import CoreBluetooth

/// CBCentralManager モジュールが Interactor から要求する範囲だけを切り出した境界。
/// スキャン専用。接続 API はここから見えない。
@MainActor
protocol CBCentralManagerInteractorInput: AnyObject {

    // MARK: 読み取り

    /// CBCentralManager の現在の状態を返す。Interactor は状態を保持せず、その都度問い合わせて返す。
    func currentState() -> CBManagerState

    /// スキャン中に発見した Discovery の一覧（identifier で重複排除済み）を返す。
    /// CBCentralManager は一覧を保持しないため Interactor が蓄積するが、その配列は private とし、
    /// 公開はこのクエリ関数で行う（保持を外へ晒さない）。
    func discoveries() -> [Discovery]

    /// discoveries / state 変化通知
    var onChange: (() -> Void)? { get set }

    // MARK: 操作

    /// スキャンを開始する。前提条件として CBCentralManager の state が .poweredOn でなければならず、
    /// 違反は `CBCentralManagerError.notPoweredOn` を throws して呼び出し側へ伝える。Void + guard + silent
    /// return では関数が走ったかどうかを呼び出し側が区別できないため、契約を throws で型に出している。
    /// - Parameters:
    ///   - filterNUS: true の場合 NUS サービス UUID でフィルタリングする
    ///   - allowDuplicates: true の場合重複した発見を許可する
    func startScan(filterNUS: Bool, allowDuplicates: Bool) throws

    /// スキャンを停止する。スキャン中でない場合は `CBCentralManagerError.notScanning` を throws する。
    func stopScan() throws
}
