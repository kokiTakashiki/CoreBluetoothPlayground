//
//  CBCentralScanInteractor.swift
//  CentralsFeature
//

import CBPlaygroundCore
import CoreBluetooth
import Foundation

/// スキャン専用の CBCentralManager 具象 Interactor。
/// `CBCentralManagerInteractorInput` を実装し、CBCentralManagerDelegate を処理する。
/// CBCentralManager は queue: .main で初期化するため、デリゲートコールバックはメインスレッドで到達する。
@MainActor
final class CBCentralScanInteractor: NSObject {

    // MARK: Static Properties

    private static let logLabel = "CBCentralManager"

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
    func cbState() -> CBManagerState {
        centralManager.state
    }

    /// 蓄積した発見結果を返す（内部配列は private、公開はこの関数のみ）。
    func discoveries() -> [Discovery] {
        discovered
    }

    func startScan(filterNUS: Bool, allowDuplicates: Bool) {
        guard centralManager.state == .poweredOn
        else {
            let reason = stateDescription(for: centralManager.state)
            log("⚠️ スキャン開始できません: \(reason)")
            return
        }

        discovered = []
        onChange?()

        let serviceUUIDs: [CBUUID]? = filterNUS ? [BLEConstants.nusService] : nil
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)

        let filterDesc = filterNUS ? "NUS フィルタ ON" : "フィルタなし"
        let dupDesc = allowDuplicates ? "重複許可 ON" : "重複許可 OFF"
        log("🔍 スキャン開始 [\(filterDesc), \(dupDesc)]")
    }

    func stopScan() {
        guard centralManager.isScanning
        else {
            return
        }
        centralManager.stopScan()
        log("⏹ スキャン停止 (発見数: \(discovered.count))")
    }

    // MARK: Private

    private func log(_ message: String) {
        BLELog.log(Self.logLabel, message)
    }

    private func stateDescription(for cbState: CBManagerState) -> String {
        switch cbState {
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
            "Bluetooth が利用できません (state=\(cbState.rawValue))"
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension CBCentralScanInteractor: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let desc = centralStateDescription(for: central.state)
        log("📡 状態変化: \(desc)")
        onChange?()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let discovery = Discovery(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        let name = peripheral.name ?? "(no name)"
        let idPrefix = peripheral.identifier.uuidString.prefix(8)

        if let index = discovered.firstIndex(where: { $0.peripheral.identifier == peripheral.identifier }) {
            discovered[index] = discovery
            log("↻ 更新: \(name) [\(idPrefix)…] RSSI=\(RSSI)")
        }
        else {
            discovered.append(discovery)
            log("✚ 発見: \(name) [\(idPrefix)…] RSSI=\(RSSI)")
        }
        onChange?()
    }

    private func centralStateDescription(for cbState: CBManagerState) -> String {
        switch cbState {
        case .unknown: "unknown"
        case .resetting: "resetting"
        case .unsupported: "unsupported"
        case .unauthorized: "unauthorized"
        case .poweredOff: "poweredOff"
        case .poweredOn: "poweredOn"
        @unknown default: "unknown(\(cbState.rawValue))"
        }
    }
}
