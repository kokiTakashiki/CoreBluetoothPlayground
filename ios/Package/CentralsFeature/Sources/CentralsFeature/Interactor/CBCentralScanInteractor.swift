//
//  CBCentralScanInteractor.swift
//  CentralsFeature
//

import CBPlaygroundCore
import CBPlaygroundLogging
import CoreBluetooth
import Foundation

/// スキャン専用の CBCentralManager 具象 Interactor。
/// `CBCentralManagerInteractorInput` を実装し、CBCentralManagerDelegate を処理する。
/// CBCentralManager を `queue: .main` で初期化するため、デリゲートコールバックはメインスレッドで到達する
/// （`@MainActor` 隔離と矛盾しない）。
@MainActor
final class CBCentralScanInteractor: NSObject {

    // MARK: Properties

    var onChange: (() -> Void)?

    /// 発見結果の蓄積。CBCentralManager は一覧を保持しないため Interactor が持つが、完全に private とし
    /// 公開は `discoveries()` 経由のみとする。
    private var discovered: [Discovery] = []

    private var centralManager: CBCentralManager!

    // MARK: Lifecycle

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
}

// MARK: - CBCentralManagerInteractorInput

extension CBCentralScanInteractor: CBCentralManagerInteractorInput {
    /// 状態は保持せず、その都度 CBCentralManager に問い合わせて返す。
    func currentState() -> CBManagerState {
        centralManager.state
    }

    /// 蓄積した発見結果を返す（内部配列は private、公開はこの関数のみ）。
    func discoveries() -> [Discovery] {
        discovered
    }

    /// スキャンを開始する。`state == .poweredOn` でない場合は `CBCentralManagerError.notPoweredOn` を
    /// throws する。
    @BLELog(message: "スキャン開始", label: "CBCentralManager")
    func startScan(filterNUS: Bool, allowDuplicates: Bool) throws {
        guard centralManager.state == .poweredOn
        else {
            throw CBCentralManagerError.notPoweredOn(centralManager.state)
        }
        discovered = []
        onChange?()
        let serviceUUIDs: [CBUUID]? = filterNUS ? [BLEConstants.nusService] : nil
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
    }

    /// スキャンを停止する。スキャン中でない場合は `CBCentralManagerError.notScanning` を throws する。
    @BLELog(message: "スキャン停止", label: "CBCentralManager")
    func stopScan() throws {
        guard centralManager.isScanning
        else {
            throw CBCentralManagerError.notScanning
        }
        centralManager.stopScan()
    }
}

// MARK: - CBCentralManagerDelegate

extension CBCentralScanInteractor: @preconcurrency CBCentralManagerDelegate {
    /// CBCentralManagerDelegate の要件であり戻り値は持てない。ログと状態の解釈は `@BLELog` を付けた
    /// `recordStateChange(_:)` に委ね、このメソッド自体はログを持たない（1 メソッド 1 ログの原則を守る）。
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        recordStateChange(central.state)
        onChange?()
    }

    /// CBCentralManagerDelegate の要件であり戻り値は持てない。発見の蓄積・更新と結末ログは
    /// `@BLELog` を付けた `record(_:)` に委ね、このメソッド自体はログを持たない。
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let discovery = Discovery(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        record(discovery)
        onChange?()
    }

    /// 状態変化を解釈して結末文字列を返す。`@BLELog` が exit で 1 行記録する。
    @discardableResult
    @BLELog(message: "状態変化", label: "CBCentralManager")
    private func recordStateChange(_ state: CBManagerState) -> String {
        centralStateDescription(for: state)
    }

    /// 発見結果を蓄積（同一識別子なら更新、無ければ追加）し、結末文字列を返す。
    /// 更新と追加で別ログを出していたのを 1 つの結末文字列に集約し、`@BLELog` が exit で 1 行記録する。
    @discardableResult
    @BLELog(message: "発見", label: "CBCentralManager")
    private func record(_ discovery: Discovery) -> String {
        let peripheral = discovery.peripheral
        let name = peripheral.name ?? "(no name)"
        let identifierPrefix = peripheral.identifier.uuidString.prefix(8)

        if let index = discovered.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
            discovered[index] = discovery
            return "更新 \(name) [\(identifierPrefix)…] RSSI=\(discovery.rssi)"
        }
        else {
            discovered.append(discovery)
            return "追加 \(name) [\(identifierPrefix)…] RSSI=\(discovery.rssi)"
        }
    }

    private func centralStateDescription(for state: CBManagerState) -> String {
        switch state {
        case .unknown: "unknown"
        case .resetting: "resetting"
        case .unsupported: "unsupported"
        case .unauthorized: "unauthorized"
        case .poweredOff: "poweredOff"
        case .poweredOn: "poweredOn"
        @unknown default: "unknown(\(state.rawValue))"
        }
    }
}
