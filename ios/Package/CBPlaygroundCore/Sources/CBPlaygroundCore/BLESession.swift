//
//  BLESession.swift
//  CBPlaygroundCore
//

import CoreBluetooth
import Foundation

// MARK: - BLESessionError

/// BLESession が投げるエラー型。CoreBluetooth から受け取った NSError は
/// `underlying` に包んで原因を保持する。
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

// MARK: - SendableBox

//
// CBPeripheral / CBService / CBCharacteristic / CBDescriptor は Swift 6 で Sendable 非準拠。
// BLESession は @MainActor に閉じており、AsyncStream.yield / continuation.resume の
// 呼び出し側と消費側は必ず同じ Main Actor 上で動く（CBCentralManager queue: .main）。
// そのため @unchecked Sendable でラップして Sendable 制約を通過させる。
// コンパイラが証明できない部分を実装者が「すべて Main Actor 上で動く」として保証する。

private struct SendableBox<Value>: @unchecked Sendable {
    let value: Value
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

    private var centralManager: CBCentralManager!

    // MARK: Scan

    private var scanContinuation: AsyncStream<Discovery>.Continuation?

    // MARK: waitUntilPoweredOn

    private var poweredOnContinuations: [CheckedContinuation<Void, Never>] = []

    // MARK: connect

    /// peripheral.identifier → continuation
    private var connectContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]

    // MARK: discoverServices

    /// peripheral.identifier → continuation (wrapped for Sendable)
    private var discoverServicesContinuations: [UUID: CheckedContinuation<SendableBox<[CBService]>, Error>] = [:]

    // MARK: discoverCharacteristics

    /// service.uuid → continuation (wrapped for Sendable)
    private var discoverCharacteristicsContinuations:
        [CBUUID: CheckedContinuation<SendableBox<[CBCharacteristic]>, Error>] = [:]

    // MARK: discoverDescriptors

    /// characteristic.uuid → continuation (wrapped for Sendable)
    private var discoverDescriptorsContinuations:
        [CBUUID: CheckedContinuation<SendableBox<[CBDescriptor]>, Error>] = [:]

    // MARK: disconnectionEvents

    private var disconnectionEventsContinuation: AsyncStream<SendableBox<CBPeripheral>>.Continuation?

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

    /// BLE スキャンを開始し、発見イベントを流す AsyncStream を返す。
    /// `stopScan()` が呼ばれると stream が finish する。
    public func startScan(serviceUUIDs: [CBUUID]?, allowDuplicates: Bool) -> AsyncStream<Discovery> {
        // 前回の stream が残っていれば finish する
        scanContinuation?.finish()
        scanContinuation = nil

        let stream = AsyncStream<Discovery> { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            scanContinuation = continuation
            continuation.onTermination = { [weak self] _ in
                // stream が外側からキャンセルされた場合もスキャン停止
                Task { @MainActor in
                    self?.centralManager.stopScan()
                    self?.scanContinuation = nil
                }
            }
        }

        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
        log("スキャン開始 serviceUUIDs=\(serviceUUIDs?.map(\.uuidString) ?? ["nil"]) allowDuplicates=\(allowDuplicates)")

        return stream
    }

    /// スキャンを停止し、startScan で返した stream を finish させる。
    public func stopScan() {
        centralManager.stopScan()
        scanContinuation?.finish()
        scanContinuation = nil
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
        let box = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<SendableBox<[CBService]>, Error>) in
            discoverServicesContinuations[identifier] = continuation
            peripheral.discoverServices(serviceUUIDs)
        }
        return box.value
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
        let box = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<SendableBox<[CBCharacteristic]>, Error>) in
            discoverCharacteristicsContinuations[key] = continuation
            peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        }
        return box.value
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
        let box = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<SendableBox<[CBDescriptor]>, Error>) in
            discoverDescriptorsContinuations[key] = continuation
            peripheral.discoverDescriptors(for: characteristic)
        }
        return box.value
    }

    /// ペリフェラルの切断イベントを流す AsyncStream（非要求イベント）。
    /// 呼び出し側がイテレートすることで didDisconnect を受け取れる。
    public func disconnectionEvents() -> AsyncStream<CBPeripheral> {
        // 既存の stream を差し替える
        disconnectionEventsContinuation?.finish()
        // CBPeripheral は Sendable 非準拠のため内部は SendableBox でラップし、外部 API では CBPeripheral を返す
        let (innerStream, innerContinuation) = AsyncStream<SendableBox<CBPeripheral>>.makeStream()
        disconnectionEventsContinuation = innerContinuation
        return AsyncStream<CBPeripheral> { continuation in
            Task {
                for await box in innerStream {
                    continuation.yield(box.value)
                }
                continuation.finish()
            }
        }
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
            // poweredOn でなくなった場合はスキャン stream を終了させる
            scanContinuation?.finish()
            scanContinuation = nil
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let discovery = Discovery(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        scanContinuation?.yield(discovery)
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
        disconnectionEventsContinuation?.yield(SendableBox(value: peripheral))

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
            let services = peripheral.services ?? []
            log("サービス探索完了: \(services.count) 件")
            continuation.resume(returning: SendableBox(value: services))
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
            let characteristics = service.characteristics ?? []
            log("キャラクタリスティック探索完了: service=\(key.uuidString.prefix(8))… \(characteristics.count) 件")
            continuation.resume(returning: SendableBox(value: characteristics))
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
            let descriptors = characteristic.descriptors ?? []
            log("記述子探索完了: characteristic=\(key.uuidString.prefix(8))… \(descriptors.count) 件")
            continuation.resume(returning: SendableBox(value: descriptors))
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
