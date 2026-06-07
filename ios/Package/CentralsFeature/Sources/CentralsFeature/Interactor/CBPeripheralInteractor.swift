//
//  CBPeripheralInteractor.swift
//  CentralsFeature
//

import CBPlaygroundCore
import CBPlaygroundLogging
import CoreBluetooth
import Foundation

/// CBPeripheral VIPER モジュールの具象 Interactor。
/// 操作は共有 `BLESession` へ委譲する。スキャンで発見した一覧は private に蓄積し、
/// `discoveries()` 経由でのみ公開する。
///
/// ログの観察軸は CBPeripheral インターフェースなので `label: "CBPeripheral"` を明示する規約。
@MainActor
final class CBPeripheralInteractor {

    // MARK: Properties

    var onChange: (() -> Void)?

    private var discovered: [Discovery] = []

    private let session: BLESession

    // MARK: Lifecycle

    init(session: BLESession) {
        self.session = session
    }

    // MARK: Functions

    // MARK: Private

    /// 1 件の発見を蓄積に反映する（同一 identifier は更新、新規は追記）。
    /// 一覧の蓄積結果（追加か更新か）を区別するため、振り分け先の `@BLELog` メソッドで結末を取る。
    private func handleDiscovery(_ discovery: Discovery) {
        let peripheral = discovery.peripheral
        if let index = discovered.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
            recordUpdated(discovery, at: index)
        }
        else {
            recordAdded(discovery)
        }
        onChange?()
    }

    /// 既知 identifier の再広告を反映する。
    @BLELog(message: "発見(再広告)", label: "CBPeripheral")
    private func recordUpdated(_ discovery: Discovery, at index: Int) {
        discovered[index] = discovery
    }

    /// 未知 identifier の発見を蓄積に追加する。
    @BLELog(message: "発見(新規)", label: "CBPeripheral")
    private func recordAdded(_ discovery: Discovery) {
        discovered.append(discovery)
    }
}

// MARK: - CBPeripheralInteractorInput

extension CBPeripheralInteractor: CBPeripheralInteractorInput {

    func discoveries() -> [Discovery] {
        discovered
    }

    /// NUS フィルタでスキャンを開始する。`state == .poweredOn` でない場合は throws で押し出す（D-016）。
    @BLELog(message: "スキャン開始", label: "CBPeripheral")
    func startScan() throws {
        guard session.currentState() == .poweredOn
        else {
            throw CBCentralManagerError.notPoweredOn(session.currentState())
        }
        discovered = []
        onChange?()
        // 発見は Main Actor 同期コールバックで受け取り、ここで蓄積する。
        session.onDiscovery = { [weak self] discovery in
            self?.handleDiscovery(discovery)
        }
        session.startScan(serviceUUIDs: [BLEConstants.nusService], allowDuplicates: false)
    }

    /// スキャンを停止する。スキャン中でない場合は throws で押し出す（D-016）。
    @BLELog(message: "スキャン停止", label: "CBPeripheral")
    func stopScan() throws {
        guard session.isScanning
        else {
            throw CBCentralManagerError.notScanning
        }
        session.onDiscovery = nil
        session.stopScan()
    }

    /// ペリフェラルへ接続する。BLESession 側の `@BLELog` で接続の成功・失敗が記録されるため、
    /// Interactor 側では追加でログを取らない（観察軸 = BLESession の 1 行で完結する）。
    func connect(_ peripheral: CBPeripheral) async throws {
        try await session.connect(peripheral)
    }

    /// 切断要求の fire-and-forget。BLESession の `@BLELog` でログを取るため Interactor 側では取らない。
    func disconnect(_ peripheral: CBPeripheral) {
        session.disconnect(peripheral)
    }

    /// サービス探索。BLESession 側の `@BLELog` が自動成功・自動失敗ログを取るため Interactor 側では取らない。
    func discoverServices(for peripheral: CBPeripheral) async throws -> [CBService] {
        try await session.discoverServices(nil, for: peripheral)
    }

    /// キャラクタリスティック探索。BLESession 側でログ済み。
    func discoverCharacteristics(
        for service: CBService,
        on peripheral: CBPeripheral
    ) async throws -> [CBCharacteristic] {
        try await session.discoverCharacteristics(nil, for: service, on: peripheral)
    }

    /// 記述子探索。BLESession 側でログ済み。
    func discoverDescriptors(
        for characteristic: CBCharacteristic,
        on peripheral: CBPeripheral
    ) async throws -> [CBDescriptor] {
        try await session.discoverDescriptors(for: characteristic, on: peripheral)
    }
}
