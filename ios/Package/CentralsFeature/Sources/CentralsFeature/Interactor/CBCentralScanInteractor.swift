//
//  CBCentralScanInteractor.swift
//  CentralsFeature
//

import CBPlaygroundCore
import CBPlaygroundLogging
import CoreBluetooth
import Foundation

/// スキャン専用の CBCentralManager 具象 Interactor。
/// `CBCentralManagerInteractorInput` を実装し、CBCentralManager の所有・CBCentralManagerDelegate の処理は
/// 共有 `BLESession`（async/await ラッパ）へ移譲する。Interactor はスキャン操作・発見イベントの蓄積・状態の
/// 読み戻しに専念する。delegate から来る `centralManagerDidUpdateState` の状態変化ログは BLESession 側で
/// `@DynamicBLELog` として取るため、Interactor からは扱わない。
@MainActor
final class CBCentralScanInteractor {

    // MARK: Properties

    var onChange: (() -> Void)?

    /// 発見結果の蓄積。BLESession の onDiscovery コールバックで受け取るが、完全に private とし
    /// 公開は `discoveries()` 経由のみとする。
    private var discovered: [Discovery] = []

    private let session: BLESession

    // MARK: Lifecycle

    init(session: BLESession) {
        self.session = session
        // BLESession の CBCentralManager 状態変化を Interactor 利用側にも橋渡しする。
        // BLESession 自身は状態変化ログを @DynamicBLELog で出すが、上位層には変化通知が要るので別経路で配る。
        session.onStateChange = { [weak self] in
            self?.onChange?()
        }
    }
}

// MARK: - CBCentralManagerInteractorInput

extension CBCentralScanInteractor: CBCentralManagerInteractorInput {

    /// 状態は保持せず、その都度 BLESession 経由で CBCentralManager に問い合わせて返す。
    func currentState() -> CBManagerState {
        session.currentState()
    }

    /// 蓄積した発見結果を返す（内部配列は private、公開はこの関数のみ）。
    func discoveries() -> [Discovery] {
        discovered
    }

    /// スキャンを開始する。`state == .poweredOn` でない場合は `CBCentralManagerError.notPoweredOn` を
    /// throws する。発見イベントは BLESession の `onDiscovery` を購読して同期蓄積する。
    @BLELog(message: "スキャン開始", label: "CBCentralManager")
    func startScan(filterNUS: Bool, allowDuplicates: Bool) throws {
        guard session.currentState() == .poweredOn
        else {
            throw CBCentralManagerError.notPoweredOn(session.currentState())
        }
        discovered = []
        onChange?()
        let serviceUUIDs: [CBUUID]? = filterNUS ? [BLEConstants.nusService] : nil
        // 発見は Main Actor 同期コールバックで受け取り、ここで蓄積する。
        session.onDiscovery = { [weak self] discovery in
            self?.handleDiscovery(discovery)
        }
        session.startScan(serviceUUIDs: serviceUUIDs, allowDuplicates: allowDuplicates)
    }

    /// スキャンを停止する。スキャン中でない場合は `CBCentralManagerError.notScanning` を throws する。
    @BLELog(message: "スキャン停止", label: "CBCentralManager")
    func stopScan() throws {
        guard session.isScanning
        else {
            throw CBCentralManagerError.notScanning
        }
        session.onDiscovery = nil
        session.stopScan()
    }

    // MARK: Private

    /// BLESession の onDiscovery で受けた 1 件を蓄積に反映する。新規発見か既知デバイスの再広告かで
    /// 観察上の意味が違うため、ここで分岐して別々の `@BLELog` メソッドへ振り分ける。
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

    /// 既知 identifier の再広告を反映する。観察上は「同じデバイスが再び見えた」イベントで、追加とは
    /// 区別したい（広告周期や RSSI の揺れを見る軸）。`@BLELog` の message で「再広告」を明示する。
    @BLELog(message: "発見(再広告)", label: "CBCentralManager")
    private func recordUpdated(_ discovery: Discovery, at index: Int) {
        discovered[index] = discovery
    }

    /// 未知 identifier の発見を蓄積に追加する。`@BLELog` の message で「新規」を明示する。
    @BLELog(message: "発見(新規)", label: "CBCentralManager")
    private func recordAdded(_ discovery: Discovery) {
        discovered.append(discovery)
    }
}
