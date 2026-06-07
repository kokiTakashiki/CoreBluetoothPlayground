//
//  CBPeripheralPresenter.swift
//  CentralsFeature
//

import CBPlaygroundCore
import CoreBluetooth
import Foundation

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

    // MARK: Static Properties

    private static let logLabel = "CBPeripheral"

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
        state = .scanning
        interactor.startScan()
        renderCurrentState()
    }

    func onStopScanTapped() {
        interactor.stopScan()
        state = .disconnected
        renderCurrentState()
    }

    func onPeripheralSelected(at index: Int) {
        let discoveries = interactor.discoveries()
        guard index < discoveries.count else {
            return
        }
        let discovery = discoveries[index]
        let peripheral = discovery.peripheral

        interactor.stopScan()
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
            // 接続なしの場合はスキャン停止のみ（MECE）
            interactor.stopScan()
        }
    }

    // MARK: Private - connect & discover

    private func connectAndDiscover(peripheral: CBPeripheral) async {
        do {
            try await interactor.connect(peripheral)
            BLELog.log(Self.logLabel, "接続成功: \(peripheral.name ?? "(no name)")")

            state = .discovering
            renderCurrentState()

            let services = try await interactor.discoverServices(for: peripheral)
            BLELog.log(Self.logLabel, "サービス探索完了: \(services.count) 件")

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
            BLELog.log(Self.logLabel, "探索エラー: \(error.localizedDescription)", level: .error)
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
