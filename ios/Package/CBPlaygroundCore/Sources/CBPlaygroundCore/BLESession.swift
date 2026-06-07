//
//  BLESession.swift
//  CBPlaygroundCore
//

import CBPlaygroundLogging
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
///
/// **ログ規約:** ログ取得は `@BLELog` / `@DynamicBLELog` 経由のみ。型名（BLESession）が
/// そのまま観察軸になるため `label:` は省略しマクロの自動採番に任せる（label の運用規約：
/// 実装者の型名ではなく観察対象 = インターフェース名を使う。BLESession は観察対象そのもの）。
@MainActor
public final class BLESession: NSObject {

    // MARK: Properties

    /// 発見イベントを配る Main Actor 同期コールバック。Interactor が設定する。
    public var onDiscovery: ((Discovery) -> Void)?

    /// CBCentralManager の状態変化を上位層に橋渡しするコールバック。BLESession は状態変化ログを
    /// `@DynamicBLELog` で自身に取り込むが、Interactor 側にも変化通知が要るのでこの経路で配る。
    public var onStateChange: (() -> Void)?

    // MARK: Scan

    /// スキャン中かどうか。発見コールバックを配るかどうかの判定に使う。
    /// `stopScan` の前提条件チェックに利用するため、外からも読めるようにする（書き込みは BLESession 内のみ）。
    public private(set) var isScanning = false

    private var centralManager: CBCentralManager!

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

    /// CBCentralManager を `queue: .main` で生成し、CBCentralManagerDelegate を引き受ける。
    /// `@BLELog` はメソッド宣言にのみ付与でき初期化子に付けられないため、初期化は無音とする。
    /// 状態変化（最初の `centralManagerDidUpdateState` で .unknown → .poweredOn など）が
    /// `@DynamicBLELog` で観察されるため、観察軸として失われる情報はない。
    override public init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: Functions

    // MARK: Public API

    /// CBCentralManager の現在の状態を返す（read-through）。観察対象でない計算的 getter なのでログは付けない。
    public func currentState() -> CBManagerState {
        centralManager.state
    }

    /// Bluetooth が poweredOn になるまで待つ。既に poweredOn なら即 return。
    @BLELog(message: "poweredOn 待機")
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
    @BLELog(message: "スキャン開始")
    public func startScan(serviceUUIDs: [CBUUID]?, allowDuplicates: Bool) {
        isScanning = true
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
    }

    /// スキャンを停止し、発見コールバックの配送を止める。
    @BLELog(message: "スキャン停止")
    public func stopScan() {
        isScanning = false
        centralManager.stopScan()
    }

    /// ペリフェラルへ接続する。didConnect で成功、didFailToConnect で `connectionFailed` を throw。
    @BLELog(message: "接続")
    public func connect(_ peripheral: CBPeripheral) async throws {
        let identifier = peripheral.identifier
        guard connectContinuations[identifier] == nil
        else {
            throw BLESessionError.alreadyInProgress
        }
        retainedPeripherals[identifier] = peripheral
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connectContinuations[identifier] = continuation
            centralManager.connect(peripheral, options: nil)
        }
    }

    /// ペリフェラルを切断する（応答不要の fire-and-forget）。
    @BLELog(message: "切断要求")
    public func disconnect(_ peripheral: CBPeripheral) {
        centralManager.cancelPeripheralConnection(peripheral)
    }

    /// サービスを探索する。peripheral.delegate を自身に設定してから実行する。
    /// throws のため `@BLELog` の自動成功・自動失敗ログでカバーできる。
    @BLELog(message: "サービス探索")
    public func discoverServices(_ serviceUUIDs: [CBUUID]?, for peripheral: CBPeripheral) async throws -> [CBService] {
        let identifier = peripheral.identifier
        guard discoverServicesContinuations[identifier] == nil
        else {
            throw BLESessionError.alreadyInProgress
        }
        peripheral.delegate = self
        // continuation には制御フロー（Void/Error）のみ載せ、結果は復帰後に Main Actor 上で読み戻す。
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            discoverServicesContinuations[identifier] = continuation
            peripheral.discoverServices(serviceUUIDs)
        }
        return peripheral.services ?? []
    }

    /// キャラクタリスティックを探索する。
    @BLELog(message: "キャラクタリスティック探索")
    public func discoverCharacteristics(
        _ characteristicUUIDs: [CBUUID]?,
        for service: CBService,
        on peripheral: CBPeripheral
    ) async throws -> [CBCharacteristic] {
        let key = service.uuid
        guard discoverCharacteristicsContinuations[key] == nil
        else {
            throw BLESessionError.alreadyInProgress
        }
        peripheral.delegate = self
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            discoverCharacteristicsContinuations[key] = continuation
            peripheral.discoverCharacteristics(characteristicUUIDs, for: service)
        }
        return service.characteristics ?? []
    }

    /// 記述子を探索する。
    @BLELog(message: "記述子探索")
    public func discoverDescriptors(
        for characteristic: CBCharacteristic,
        on peripheral: CBPeripheral
    ) async throws -> [CBDescriptor] {
        let key = characteristic.uuid
        guard discoverDescriptorsContinuations[key] == nil
        else {
            throw BLESessionError.alreadyInProgress
        }
        peripheral.delegate = self
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            discoverDescriptorsContinuations[key] = continuation
            peripheral.discoverDescriptors(for: characteristic)
        }
        return characteristic.descriptors ?? []
    }
}

// MARK: - CBCentralManagerDelegate

extension BLESession: @preconcurrency CBCentralManagerDelegate {

    /// CBCentralManagerDelegate の要件で戻り値を持てず、`CBManagerState` の値ごとに本文を変えたい。
    /// `@BLELog` の固定 message では表現できないため、切り札の `@DynamicBLELog` を使う。
    @DynamicBLELog(failureLabel: "BLESession", source: { (central: CBCentralManager) in
        let message = switch central.state {
        case .unknown: "状態変化 unknown"
        case .resetting: "状態変化 resetting"
        case .unsupported: "状態変化 unsupported"
        case .unauthorized: "状態変化 unauthorized"
        case .poweredOff: "状態変化 poweredOff"
        case .poweredOn: "状態変化 poweredOn"
        @unknown default: "状態変化 unknown(\(central.state.rawValue))"
        }
        return DynamicBLELogPayload(level: .info, message: message, label: "BLESession")
    })
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
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
        onStateChange?()
    }

    /// 発見イベント。CBCentralManagerDelegate の要件で戻り値は持てず、対象（peripheral）の情報を message に
    /// 載せたいため `@DynamicBLELog` で peripheral.name を含むメッセージを動的に組み立てる。
    @DynamicBLELog(failureLabel: "BLESession", source: { (
        _: CBCentralManager,
        peripheral: CBPeripheral,
        _: [String: Any],
        rssi: NSNumber
    ) in
        let name = peripheral.name ?? "(no name)"
        let identifierPrefix = peripheral.identifier.uuidString.prefix(8)
        return DynamicBLELogPayload(
            level: .debug,
            message: "発見 \(name) [\(identifierPrefix)…] RSSI=\(rssi)",
            label: "BLESession"
        )
    })
    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard isScanning
        else {
            // スキャン停止後・poweredOn でない時に届いたコールバックは無視（MECE: 配送対象外）
            return
        }
        let discovery = Discovery(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        // 同一アクター（Main）内の同期呼び出し。隔離境界を跨がないので Discovery は Sendable 不要。
        onDiscovery?(discovery)
    }

    /// 接続成功イベント。観察対象（接続できた peripheral 名）を message に出したいため `@DynamicBLELog`。
    @DynamicBLELog(failureLabel: "BLESession", source: { (_: CBCentralManager, peripheral: CBPeripheral) in
        let name = peripheral.name ?? "(no name)"
        let identifierPrefix = peripheral.identifier.uuidString.prefix(8)
        return DynamicBLELogPayload(
            level: .info,
            message: "接続成功 \(name) [\(identifierPrefix)…]",
            label: "BLESession"
        )
    })
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let identifier = peripheral.identifier
        guard let continuation = connectContinuations[identifier]
        else {
            // 対応する continuation がない場合は接続を受理するだけ（MECE: 待機なしでも正常）
            return
        }
        connectContinuations[identifier] = nil
        continuation.resume()
    }

    /// 接続失敗イベント。`@BLELog` では error を message に組み込めないため `@DynamicBLELog` を使う。
    @DynamicBLELog(
        failureLabel: "BLESession",
        source: { (_: CBCentralManager, peripheral: CBPeripheral, error: Error?) in
            let name = peripheral.name ?? "(no name)"
            let identifierPrefix = peripheral.identifier.uuidString.prefix(8)
            let errorText = error?.localizedDescription ?? "nil"
            return DynamicBLELogPayload(
                level: .error,
                message: "接続失敗 \(name) [\(identifierPrefix)…] error=\(errorText)",
                label: "BLESession"
            )
        }
    )
    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let identifier = peripheral.identifier
        retainedPeripherals[identifier] = nil
        guard let continuation = connectContinuations[identifier]
        else {
            // 待機なしの場合は無視（MECE: 接続中でなければコールバックは無効）
            return
        }
        connectContinuations[identifier] = nil
        continuation.resume(throwing: BLESessionError.connectionFailed(error))
    }

    /// 切断イベント。error 付きの message を動的に組み立てたいため `@DynamicBLELog`。
    @DynamicBLELog(
        failureLabel: "BLESession",
        source: { (_: CBCentralManager, peripheral: CBPeripheral, error: Error?) in
            let name = peripheral.name ?? "(no name)"
            let identifierPrefix = peripheral.identifier.uuidString.prefix(8)
            let errorText = error?.localizedDescription ?? "nil"
            return DynamicBLELogPayload(
                level: .info,
                message: "切断 \(name) [\(identifierPrefix)…] error=\(errorText)",
                label: "BLESession"
            )
        }
    )
    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let identifier = peripheral.identifier
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
        guard let continuation = discoverServicesContinuations[identifier]
        else {
            // 待機なしの場合は無視（MECE: 非要求 or タイムアウト後に届いた場合）
            return
        }
        discoverServicesContinuations[identifier] = nil

        if let error {
            continuation.resume(throwing: error)
        }
        else {
            // 非 Sendable な services は continuation に載せず、復帰後に Main Actor 側で読み戻す。
            continuation.resume()
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        let key = service.uuid
        guard let continuation = discoverCharacteristicsContinuations[key]
        else {
            // 待機なしの場合は無視（MECE: 非要求 or タイムアウト後）
            return
        }
        discoverCharacteristicsContinuations[key] = nil

        if let error {
            continuation.resume(throwing: error)
        }
        else {
            continuation.resume()
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverDescriptorsFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let key = characteristic.uuid
        guard let continuation = discoverDescriptorsContinuations[key]
        else {
            // 待機なしの場合は無視（MECE: 非要求 or タイムアウト後）
            return
        }
        discoverDescriptorsContinuations[key] = nil

        if let error {
            continuation.resume(throwing: error)
        }
        else {
            continuation.resume()
        }
    }
}
