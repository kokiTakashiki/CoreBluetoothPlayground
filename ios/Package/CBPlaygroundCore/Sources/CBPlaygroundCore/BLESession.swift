//
//  BLESession.swift
//  CBPlaygroundCore
//

import CoreBluetooth
import Foundation

// MARK: - BLESessionError

/// BLESession が投げるエラー型。CoreBluetooth から受け取った NSError は
/// 各ケースの関連値（`Error?`）に包んで原因を保持する。
public enum BLESessionError: Error {
    /// Bluetooth が poweredOn 状態でない（スキャン・接続前チェック用）
    case notPoweredOn
    /// 接続に失敗した（CBCentralManager が didFailToConnect を通知）
    case connectionFailed(Error?)
    /// 切断された（操作中に didDisconnect を受けた）
    case disconnected(Error?)
    /// 同一対象に対して既に同種の操作が進行中
    case alreadyInProgress
}

// MARK: - BLESession

/// CoreBluetooth の async/await 薄いラッパ。
///
/// `CBCentralManager` を唯一所有し、`CBCentralManagerDelegate` と
/// `CBPeripheralDelegate` を担う。スキャン・接続・探索はすべてここを経由させ、
/// CBCentralManager の所有を一本化する。
///
/// **二重 resume 対策**: continuation は対象キー（peripheral.identifier /
/// service.uuid / characteristic.uuid）付きの辞書で保持し、resume 直後に
/// nil（= 削除）する。再入時は `alreadyInProgress` を throw することで
/// 同一対象への多重待ちを防ぐ。
@MainActor
public final class BLESession: NSObject {

    // MARK: Static Properties

    private static let logLabel = "BLESession"

    // MARK: Properties

    /// 発見イベントを配る Main Actor 同期コールバック。Interactor が設定する。
    public var onDiscovery: ((Discovery) -> Void)?

    private var centralManager: CBCentralManager!

    // MARK: Scan

    /// スキャン中かどうか。発見コールバックを配るかどうかの判定に使う。
    private var isScanning = false

    // MARK: waitUntilPoweredOn

    private var poweredOnContinuations: [CheckedContinuation<Void, Never>] = []

    // MARK: connect

    /// peripheral.identifier → continuation
    private var connectContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]

    // MARK: discoverServices

    /// peripheral.identifier → continuation（制御フローのみを載せ、結果は Main Actor 側で読み戻す）
    private var discoverServicesContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]

    // MARK: discoverCharacteristics

    /// service.uuid → continuation
    private var discoverCharacteristicsContinuations: [CBUUID: CheckedContinuation<Void, Error>] = [:]

    // MARK: discoverDescriptors

    /// characteristic.uuid → continuation
    private var discoverDescriptorsContinuations: [CBUUID: CheckedContinuation<Void, Error>] = [:]

    // MARK: Retained peripherals

    /// 接続・探索中のペリフェラルを強参照で保持する（ARC による解放を防ぐ）。
    private var retainedPeripherals: [UUID: CBPeripheral] = [:]

    // MARK: Lifecycle

    override public init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        log("初期化完了")
    }

    // MARK: Functions

    // MARK: Public API

    /// CBCentralManager の現在の状態を返す（read-through）。
    public func currentState() -> CBManagerState {
        centralManager.state
    }

    /// Bluetooth が poweredOn になるまで待つ。既に poweredOn なら即 return。
    public func waitUntilPoweredOn() async {
        if centralManager.state == .poweredOn {
            return
        }
        await withCheckedContinuation { continuation in
            poweredOnContinuations.append(continuation)
        }
    }

    /// BLE スキャンを開始する。発見イベントは `onDiscovery` クロージャ（Main Actor 同期）で配る。
    /// 非 Sendable な CBPeripheral を含む `Discovery` を隔離境界へ載せないため、AsyncStream ではなく
    /// 同一アクター内の同期コールバックで渡す。`stopScan()` で配送を止める。
    public func startScan(serviceUUIDs: [CBUUID]?, allowDuplicates: Bool) {
        isScanning = true
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
        log("スキャン開始 serviceUUIDs=\(serviceUUIDs?.map(\.uuidString) ?? ["nil"]) allowDuplicates=\(allowDuplicates)")
    }

    /// スキャンを停止し、発見コールバックの配送を止める。
    public func stopScan() {
        isScanning = false
        centralManager.stopScan()
        log("スキャン停止")
    }

    /// ペリフェラルへ接続する。didConnect で成功、didFailToConnect で `connectionFailed` を throw。
    public func connect(_ peripheral: CBPeripheral) async throws {
        let identifier = peripheral.identifier
        guard connectContinuations[identifier] == nil else {
            throw BLESessionError.alreadyInProgress
        }
        retainedPeripherals[identifier] = peripheral
        log("接続試行: \(peripheral.name ?? "(no name)") [\(identifier.uuidString.prefix(8))…]")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connectContinuations[identifier] = continuation
            centralManager.connect(peripheral, options: nil)
        }
    }

    /// ペリフェラルを切断する（応答不要の fire-and-forget）。
    public func disconnect(_ peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
        log("切断要求: \(peripheral.name ?? "(no name)") [\(peripheral.identifier.uuidString.prefix(8))…]")
    }

    /// サービスを探索する。peripheral.delegate を自身に設定してから実行する。
    public func discoverServices(_ serviceUUIDs: [CBUUID]?, for peripheral: CBPeripheral) async throws -> [CBService] {
        let identifier = peripheral.identifier
        guard discoverServicesContinuations[identifier] == nil else {
            throw BLESessionError.alreadyInProgress
        }
        peripheral.delegate = self
        log("サービス探索開始: \(peripheral.name ?? "(no name)")")
        // continuation には制御フロー（Void/Error）のみ載せ、結果は復帰後に Main Actor 上で読み戻す。
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            discoverServicesContinuations[identifier] = continuation
            peripheral.discoverServices(serviceUUIDs)
        }
        return peripheral.services ?? []
    }

    /// キャラクタリスティックを探索する。
    public func discoverCharacteristics(
        _ characteristicUUIDs: [CBUUID]?,
        for service: CBService,
        on peripheral: CBPeripheral
    ) async throws -> [CBCharacteristic] {
        let key = service.uuid
        guard discoverCharacteristicsContinuations[key] == nil else {
            throw BLESessionError.alreadyInProgress
        }
        peripheral.delegate = self
        log("キャラクタリスティック探索開始: service=\(service.uuid.uuidString.prefix(8))…")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            discoverCharacteristicsContinuations[key] = continuation
            peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        }
        return service.characteristics ?? []
    }

    /// 記述子を探索する。
    public func discoverDescriptors(
        for characteristic: CBCharacteristic,
        on peripheral: CBPeripheral
    ) async throws -> [CBDescriptor] {
        let key = characteristic.uuid
        guard discoverDescriptorsContinuations[key] == nil else {
            throw BLESessionError.alreadyInProgress
        }
        peripheral.delegate = self
        log("記述子探索開始: characteristic=\(characteristic.uuid.uuidString.prefix(8))…")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            discoverDescriptorsContinuations[key] = continuation
            peripheral.discoverDescriptors(for: characteristic)
        }
        return characteristic.descriptors ?? []
    }

    // MARK: Private

    private func log(_ message: String) {
        BLELog.log(Self.logLabel, message)
    }
}

// MARK: - CBCentralManagerDelegate

extension BLESession: @preconcurrency CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log("状態変化: \(stateDescription(for: central.state))")

        if central.state == .poweredOn {
            // 待機中の continuation を全て resume
            let continuations = poweredOnContinuations
            poweredOnContinuations = []
            for continuation in continuations {
                continuation.resume()
            }
        }
        else {
            // poweredOn でなくなった場合は発見コールバックの配送を止める
            isScanning = false
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard isScanning else {
            // スキャン停止後・poweredOn でない時に届いたコールバックは無視（MECE: 配送対象外）
            return
        }
        let discovery = Discovery(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        // 同一アクター（Main）内の同期呼び出し。隔離境界を跨がないので Discovery は Sendable 不要。
        onDiscovery?(discovery)
        log("発見: \(peripheral.name ?? "(no name)") [\(peripheral.identifier.uuidString.prefix(8))…] RSSI=\(RSSI)")
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let identifier = peripheral.identifier
        log("接続成功: \(peripheral.name ?? "(no name)") [\(identifier.uuidString.prefix(8))…]")
        guard let continuation = connectContinuations[identifier] else {
            // 対応する continuation がない場合は接続を受理するだけ（MECE: 待機なしでも正常）
            return
        }
        connectContinuations[identifier] = nil
        continuation.resume()
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let identifier = peripheral.identifier
        log(
            "接続失敗: \(peripheral.name ?? "(no name)") [\(identifier.uuidString.prefix(8))…] error=\(error?.localizedDescription ?? "nil")"
        )
        retainedPeripherals[identifier] = nil
        guard let continuation = connectContinuations[identifier] else {
            // 待機なしの場合は無視（MECE: 接続中でなければコールバックは無効）
            return
        }
        connectContinuations[identifier] = nil
        continuation.resume(throwing: BLESessionError.connectionFailed(error))
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let identifier = peripheral.identifier
        log(
            "切断: \(peripheral.name ?? "(no name)") [\(identifier.uuidString.prefix(8))…] error=\(error?.localizedDescription ?? "nil")"
        )
        retainedPeripherals[identifier] = nil

        // 探索系 continuation が待機中の場合（切断による強制終了）
        if let continuation = discoverServicesContinuations[identifier] {
            discoverServicesContinuations[identifier] = nil
            continuation.resume(throwing: BLESessionError.disconnected(error))
        }
        else {
            // 探索待機なし（MECE: サービス探索前に切断された場合は何もしない）
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLESession: @preconcurrency CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let identifier = peripheral.identifier
        guard let continuation = discoverServicesContinuations[identifier] else {
            // 待機なしの場合は無視（MECE: 非要求 or タイムアウト後に届いた場合）
            return
        }
        discoverServicesContinuations[identifier] = nil

        if let error {
            log("サービス探索エラー: \(error.localizedDescription)")
            continuation.resume(throwing: error)
        }
        else {
            // 非 Sendable な services は continuation に載せず、復帰後に Main Actor 側で読み戻す。
            log("サービス探索完了: \((peripheral.services ?? []).count) 件")
            continuation.resume()
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        let key = service.uuid
        guard let continuation = discoverCharacteristicsContinuations[key] else {
            // 待機なしの場合は無視（MECE: 非要求 or タイムアウト後）
            return
        }
        discoverCharacteristicsContinuations[key] = nil

        if let error {
            log("キャラクタリスティック探索エラー: service=\(key) \(error.localizedDescription)")
            continuation.resume(throwing: error)
        }
        else {
            log("キャラクタリスティック探索完了: service=\(key.uuidString.prefix(8))… \((service.characteristics ?? []).count) 件")
            continuation.resume()
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let key = characteristic.uuid
        guard let continuation = discoverDescriptorsContinuations[key] else {
            // 待機なしの場合は無視（MECE: 非要求 or タイムアウト後）
            return
        }
        discoverDescriptorsContinuations[key] = nil

        if let error {
            log("記述子探索エラー: characteristic=\(key) \(error.localizedDescription)")
            continuation.resume(throwing: error)
        }
        else {
            log("記述子探索完了: characteristic=\(key.uuidString.prefix(8))… \((characteristic.descriptors ?? []).count) 件")
            continuation.resume()
        }
    }
}

// MARK: - Private Helpers

private extension BLESession {
    func stateDescription(for state: CBManagerState) -> String {
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
