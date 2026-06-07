//
//  CBPeripheralInteractor.swift
//  CentralsFeature
//

import CBPlaygroundCore
import CoreBluetooth
import Foundation

/// CBPeripheral VIPER モジュールの具象 Interactor。
/// 操作は BLESession へ委譲する。スキャンで発見した一覧は private に蓄積し、
/// `discoveries()` 経由でのみ公開する。
@MainActor
final class CBPeripheralInteractor {

    // MARK: Static Properties

    private static let logLabel = "CBPeripheral"

    // MARK: Properties

    var onChange: (() -> Void)?

    private var discovered: [Discovery] = []

    private let session: BLESession

    private var scanTask: Task<Void, Never>?

    // MARK: Lifecycle

    init(session: BLESession) {
        self.session = session
    }

    // MARK: Functions

    // MARK: Private

    private func log(_ message: String) {
        BLELog.log(Self.logLabel, message)
    }
}

// MARK: - CBPeripheralInteractorInput

extension CBPeripheralInteractor: CBPeripheralInteractorInput {

    func discoveries() -> [Discovery] {
        discovered
    }

    func startScan() {
        guard session.currentState() == .poweredOn else {
            log("⚠️ スキャン開始できません: Bluetooth が poweredOn でありません")
            return
        }

        discovered = []
        onChange?()

        scanTask?.cancel()
        log("🔍 スキャン開始 [NUS フィルタ ON]")
        let stream = session.startScan(serviceUUIDs: [BLEConstants.nusService], allowDuplicates: false)
        scanTask = Task { [weak self] in
            for await discovery in stream {
                guard let self else {
                    return
                }
                let peripheral = discovery.peripheral
                let name = peripheral.name ?? "(no name)"
                let identifierPrefix = peripheral.identifier.uuidString.prefix(8)

                if let index = discovered.firstIndex(where: {
                    $0.peripheral.identifier == peripheral.identifier
                }) {
                    discovered[index] = discovery
                    log("↻ 更新: \(name) [\(identifierPrefix)…] RSSI=\(discovery.rssi)")
                }
                else {
                    discovered.append(discovery)
                    log("✚ 発見: \(name) [\(identifierPrefix)…] RSSI=\(discovery.rssi)")
                }
                onChange?()
            }
        }
    }

    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        session.stopScan()
        log("⏹ スキャン停止 (発見数: \(discovered.count))")
    }

    func connect(_ peripheral: CBPeripheral) async throws {
        log("接続試行: \(peripheral.name ?? "(no name)")")
        try await session.connect(peripheral)
    }

    func disconnect(_ peripheral: CBPeripheral) {
        session.disconnect(peripheral)
    }

    func discoverServices(for peripheral: CBPeripheral) async throws -> [CBService] {
        log("サービス探索: \(peripheral.name ?? "(no name)")")
        return try await session.discoverServices(nil, for: peripheral)
    }

    func discoverCharacteristics(
        for service: CBService,
        on peripheral: CBPeripheral
    ) async throws -> [CBCharacteristic] {
        log("キャラクタリスティック探索: service=\(service.uuid.uuidString.prefix(8))…")
        return try await session.discoverCharacteristics(nil, for: service, on: peripheral)
    }

    func discoverDescriptors(
        for characteristic: CBCharacteristic,
        on peripheral: CBPeripheral
    ) async throws -> [CBDescriptor] {
        log("記述子探索: characteristic=\(characteristic.uuid.uuidString.prefix(8))…")
        return try await session.discoverDescriptors(for: characteristic, on: peripheral)
    }
}
