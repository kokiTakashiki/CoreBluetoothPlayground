//
//  CBPeripheralInteractorInput.swift
//  CentralsFeature
//

import CBPlaygroundCore
import CoreBluetooth

/// CBPeripheral モジュールが Interactor から要求する範囲だけを切り出した境界。
/// スキャンで接続先を選び、接続後に GATT ツリーを探索する一連の操作を担う。
/// read/write/notify は対象外（CBCharacteristic 増分で実装）。
@MainActor
protocol CBPeripheralInteractorInput: AnyObject {

    // MARK: 読み取り

    /// スキャン中に発見した Discovery の一覧を返す。
    func discoveries() -> [Discovery]

    /// discoveries / state 変化通知
    var onChange: (() -> Void)? { get set }

    // MARK: スキャン

    /// NUS フィルタでスキャンを開始する。前提条件として CBCentralManager の state が .poweredOn でなければ
    /// ならず、違反は `CBCentralManagerError.notPoweredOn` を throws して呼び出し側へ伝える（D-016: Void +
    /// guard + silent return を避け、契約を throws で型に出す）。
    func startScan() throws

    /// スキャンを停止する。スキャン中でない場合は `CBCentralManagerError.notScanning` を throws する。
    func stopScan() throws

    // MARK: 接続・切断

    /// ペリフェラルへ接続する。
    func connect(_ peripheral: CBPeripheral) async throws

    /// ペリフェラルを切断する。
    func disconnect(_ peripheral: CBPeripheral)

    // MARK: GATT 探索

    /// サービスを探索する。
    func discoverServices(for peripheral: CBPeripheral) async throws -> [CBService]

    /// キャラクタリスティックを探索する。
    func discoverCharacteristics(for service: CBService, on peripheral: CBPeripheral) async throws -> [CBCharacteristic]

    /// 記述子を探索する。
    func discoverDescriptors(for characteristic: CBCharacteristic, on peripheral: CBPeripheral) async throws
        -> [CBDescriptor]
}
