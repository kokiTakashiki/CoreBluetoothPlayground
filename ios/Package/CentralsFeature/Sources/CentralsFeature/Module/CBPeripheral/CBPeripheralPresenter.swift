//
//  CBPeripheralPresenter.swift
//  CentralsFeature
//

import CBPlaygroundCore
import CoreBluetooth
import Foundation

// CBPeripheralPresenter はログを書かない（規約: ログは Interactor / BLESession 側の @BLELog / @DynamicBLELog で
// 取り、Presenter は UI への翻訳のみを担う）。前提条件違反は throws で受け、View に `render(errorMessage:)`
// で伝える（D-016）。

// MARK: - GATT ツリー表示用 VM

/// GATT ツリーのセクション（= サービス 1 件）
struct GATTServiceSection {
    let serviceUUID: String
    let isPrimary: Bool
    let characteristics: [GATTCharacteristicRow]
}

/// GATT ツリーのキャラクタリスティック行
struct GATTCharacteristicRow {
    let characteristicUUID: String
    let propertiesSummary: String
    let descriptors: [GATTDescriptorRow]
}

/// GATT ツリーの記述子行
struct GATTDescriptorRow {
    let descriptorUUID: String
}

// MARK: - CBPeripheralPresenterState

/// Presenter の状態機械
enum CBPeripheralPresenterState {
    case scanning
    case discovered
    case connecting
    case discovering
    case tree([GATTServiceSection])
    case disconnected
    case failed(String)
}

// MARK: - PeripheralRow

/// スキャン一覧の 1 行
struct PeripheralRow {
    let name: String
    let rssi: String
    let identifier: String
}

// MARK: - CBPeripheralViewInput

/// Presenter から View への更新インターフェース
@MainActor
protocol CBPeripheralViewInput: AnyObject {
    /// スキャン一覧と状態を反映する
    func renderDiscoveries(rows: [PeripheralRow], state: CBPeripheralPresenterState)
    /// GATT ツリーと状態を反映する
    func renderTree(sections: [GATTServiceSection], state: CBPeripheralPresenterState)
    /// 状態ラベルのみ更新する
    func renderStatus(_ state: CBPeripheralPresenterState)
    /// 前提条件違反などのエラー文面を View 側に通知する。ユーザーへの最小通知が責務であり、
    /// 表示の具体（アラート／トースト等）は実装側で選ぶ。
    func render(errorMessage: String)
}

// MARK: - CBPeripheralPresenterInput

/// View からの操作イベントを受け取る Presenter インターフェース
@MainActor
protocol CBPeripheralPresenterInput: AnyObject {
    func onViewReady()
    func onScanTapped()
    func onStopScanTapped()
    func onPeripheralSelected(at index: Int)
    func onDisconnectTapped()
    func onViewDidDisappear()
}

// MARK: - CBPeripheralPresenter

@MainActor
final class CBPeripheralPresenter: CBPeripheralPresenterInput {

    // MARK: Properties

    weak var view: (any CBPeripheralViewInput)?

    private var interactor: any CBPeripheralInteractorInput

    private var state: CBPeripheralPresenterState = .disconnected

    private var connectedPeripheral: CBPeripheral?

    // MARK: Lifecycle

    init(interactor: any CBPeripheralInteractorInput) {
        self.interactor = interactor
    }

    // MARK: Functions

    // MARK: CBPeripheralPresenterInput

    func onViewReady() {
        interactor.onChange = { [weak self] in
            self?.handleDiscoveryChange()
        }
        renderCurrentState()
    }

    func onScanTapped() {
        do {
            try interactor.startScan()
            state = .scanning
            renderCurrentState()
        }
        catch {
            // 前提条件違反（state が .poweredOn でない等）。View にエラー文面を渡して通知する。
            // ログは Interactor 側の @BLELog の catch ブランチが `→ 失敗(<error>)` で残しているため、ここでは出さない。
            view?.render(errorMessage: error.localizedDescription)
        }
    }

    func onStopScanTapped() {
        do {
            try interactor.stopScan()
            state = .disconnected
            renderCurrentState()
        }
        catch {
            // スキャン中でなかった等の前提条件違反。View にエラー文面を渡して通知する。
            view?.render(errorMessage: error.localizedDescription)
        }
    }

    func onPeripheralSelected(at index: Int) {
        let discoveries = interactor.discoveries()
        guard index < discoveries.count
        else {
            return
        }
        let discovery = discoveries[index]
        let peripheral = discovery.peripheral

        do {
            try interactor.stopScan()
        }
        catch {
            // スキャンしていない状態で行選択された等のケースは、選択 → 接続の本筋に対してノイズなので
            // ユーザーには伝えず黙殺する。失敗ログは Interactor 側の @BLELog で残る（D-016 の正常黙殺）。
        }
        connectedPeripheral = peripheral
        state = .connecting
        renderCurrentState()

        Task { [weak self] in
            guard let self else {
                return
            }
            await connectAndDiscover(peripheral: peripheral)
        }
    }

    func onDisconnectTapped() {
        if let peripheral = connectedPeripheral {
            interactor.disconnect(peripheral)
            connectedPeripheral = nil
        }
        else {
            // 接続中のペリフェラルがない場合は状態をリセットするだけ（MECE）
        }
        state = .disconnected
        renderCurrentState()
    }

    func onViewDidDisappear() {
        if let peripheral = connectedPeripheral {
            interactor.disconnect(peripheral)
            connectedPeripheral = nil
        }
        else {
            // 接続なしの場合はスキャン停止のみ（MECE）。スキャンしていない正常ケースもあるので失敗は黙殺する。
            do {
                try interactor.stopScan()
            }
            catch {
                // 画面が消えるタイミングでは元々スキャンしていない正常ケースが多く、エラー文面を出すと
                // ユーザーには無関係なノイズになる。失敗ログは Interactor 側の @BLELog で残るので黙殺する。
            }
        }
    }

    // MARK: Private - connect & discover

    private func connectAndDiscover(peripheral: CBPeripheral) async {
        // 接続・探索の成功・失敗ログは BLESession 側の @BLELog / @DynamicBLELog で取られるため、Presenter 側
        // ではログを取らず、結果を UI 状態に翻訳する責務だけを担う（規約: Presenter はログを書かない）。
        do {
            try await interactor.connect(peripheral)

            state = .discovering
            renderCurrentState()

            let services = try await interactor.discoverServices(for: peripheral)

            var sections: [GATTServiceSection] = []
            for service in services {
                let characteristics = try await interactor.discoverCharacteristics(for: service, on: peripheral)
                var characteristicRows: [GATTCharacteristicRow] = []
                for characteristic in characteristics {
                    let descriptors = try await interactor.discoverDescriptors(for: characteristic, on: peripheral)
                    let descriptorRows = descriptors.map { GATTDescriptorRow(descriptorUUID: $0.uuid.uuidString) }
                    characteristicRows.append(
                        GATTCharacteristicRow(
                            characteristicUUID: characteristic.uuid.uuidString,
                            propertiesSummary: propertiesSummary(for: characteristic.properties),
                            descriptors: descriptorRows
                        )
                    )
                }
                sections.append(
                    GATTServiceSection(
                        serviceUUID: service.uuid.uuidString,
                        isPrimary: service.isPrimary,
                        characteristics: characteristicRows
                    )
                )
            }
            state = .tree(sections)
            renderCurrentState()
        }
        catch {
            connectedPeripheral = nil
            state = .failed(error.localizedDescription)
            renderCurrentState()
        }
    }

    // MARK: Private - rendering

    private func handleDiscoveryChange() {
        switch state {
        case .scanning, .discovered:
            state = interactor.discoveries().isEmpty ? .scanning : .discovered
            renderCurrentState()
        case .connecting, .discovering, .tree, .disconnected, .failed:
            // スキャン外の状態では onChange を無視する（MECE）
            break
        }
    }

    private func renderCurrentState() {
        let rows = makePeripheralRows()
        switch state {
        case .scanning, .discovered, .disconnected, .failed:
            view?.renderDiscoveries(rows: rows, state: state)
        case .connecting, .discovering:
            view?.renderStatus(state)
        case let .tree(sections):
            view?.renderTree(sections: sections, state: state)
        }
    }

    private func makePeripheralRows() -> [PeripheralRow] {
        interactor.discoveries().map { discovery in
            PeripheralRow(
                name: discovery.peripheral.name ?? "(no name)",
                rssi: "RSSI: \(discovery.rssi)",
                identifier: String(discovery.peripheral.identifier.uuidString.prefix(8)) + "…"
            )
        }
    }

    // MARK: Private - helpers

    /// CBCharacteristicProperties の内容を読み取り可能な文字列に整形する
    private func propertiesSummary(for properties: CBCharacteristicProperties) -> String {
        var parts: [String] = []
        if properties.contains(.broadcast) {
            parts.append("broadcast")
        }
        else { /* 未設定の場合は省く */ }
        if properties.contains(.read) {
            parts.append("read")
        }
        else { /* 未設定の場合は省く */ }
        if properties.contains(.writeWithoutResponse) {
            parts.append("writeNoRsp")
        }
        else { /* 未設定の場合は省く */ }
        if properties.contains(.write) {
            parts.append("write")
        }
        else { /* 未設定の場合は省く */ }
        if properties.contains(.notify) {
            parts.append("notify")
        }
        else { /* 未設定の場合は省く */ }
        if properties.contains(.indicate) {
            parts.append("indicate")
        }
        else { /* 未設定の場合は省く */ }
        if properties.contains(.authenticatedSignedWrites) {
            parts.append("signedWrite")
        }
        else { /* 未設定の場合は省く */ }
        if properties.contains(.extendedProperties) {
            parts.append("extProps")
        }
        else { /* 未設定の場合は省く */ }
        if properties.contains(.notifyEncryptionRequired) {
            parts.append("notifyEnc")
        }
        else { /* 未設定の場合は省く */ }
        if properties.contains(.indicateEncryptionRequired) {
            parts.append("indicateEnc")
        }
        else { /* 未設定の場合は省く */ }
        return parts.isEmpty ? "(none)" : parts.joined(separator: ", ")
    }
}
