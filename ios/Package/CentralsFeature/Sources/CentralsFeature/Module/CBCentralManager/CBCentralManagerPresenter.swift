//
//  CBCentralManagerPresenter.swift
//  CentralsFeature
//

import CBPlaygroundCore
import CoreBluetooth
import Foundation

// MARK: - DeviceRow

/// Presenter が Interactor の Discovery から組み立てる表示用 VM
struct DeviceRow {

    let name: String
    let rssi: String
    let advertisementSummary: String
}

// MARK: - CBCentralManagerPresenterInput

/// View からの操作イベントを受け取る Presenter インターフェース
@MainActor
protocol CBCentralManagerPresenterInput: AnyObject {

    /// View が準備完了した直後に呼ぶ
    func onViewReady()

    /// Start ボタンがタップされた
    func onStartTapped(filterNUS: Bool, allowDuplicates: Bool)

    /// Stop ボタンがタップされた
    func onStopTapped()

    /// 画面が非表示になった（viewDidDisappear）
    func onViewDidDisappear()
}

// MARK: - CBCentralManagerPresenter

@MainActor
final class CBCentralManagerPresenter: CBCentralManagerPresenterInput {

    // MARK: Properties

    weak var view: (any CBCentralManagerViewInput)?

    private var interactor: any CBCentralManagerInteractorInput

    // MARK: Lifecycle

    init(interactor: any CBCentralManagerInteractorInput) {
        self.interactor = interactor
    }

    // MARK: Static Functions

    /// 広告データを表示用文字列に整形する（UI 結合の整形は Presenter で行う）。
    /// 広告データの各キーはいずれも任意であり、欠落は異常ではない。各 if に else を設けて
    /// 「無い場合になぜ省くか」を明示し、判断の抜けを無くす（MECE）。
    private static func summarize(_ data: [String: Any]) -> String {
        var parts: [String] = []

        if let serviceUUIDs = data[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            parts.append("services: \(serviceUUIDs.map(\.uuidString).joined(separator: ", "))")
        }
        else {
            // この広告に Service UUIDs が含まれないだけ。広告は任意キーの集合なので欠落は正常。要約から省く。
        }

        if let localName = data[CBAdvertisementDataLocalNameKey] as? String {
            parts.append("localName: \(localName)")
        }
        else {
            // ローカル名は未広告。スキャン応答側にのみ載る構成もあり、無くても異常ではない。省く。
        }

        if let txPower = data[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            parts.append("txPower: \(txPower)")
        }
        else {
            // TxPower レベルは任意。未広告なら距離推定に使えないだけで異常ではない。省く。
        }

        if let isConnectable = data[CBAdvertisementDataIsConnectable] as? NSNumber {
            parts.append("connectable: \(isConnectable.boolValue)")
        }
        else {
            // 接続可否フラグを広告側が明示していない。false と断定せず「不明」として省く。
        }

        return parts.isEmpty ? "(no data)" : parts.joined(separator: ", ")
    }

    // MARK: Functions

    func onViewReady() {
        interactor.onChange = { [weak self] in
            self?.handleChange()
        }
        handleChange()
    }

    func onStartTapped(filterNUS: Bool, allowDuplicates: Bool) {
        interactor.startScan(filterNUS: filterNUS, allowDuplicates: allowDuplicates)
        view?.render(rows: makeRows(), scanning: true)
    }

    func onStopTapped() {
        interactor.stopScan()
        view?.render(rows: makeRows(), scanning: false)
    }

    func onViewDidDisappear() {
        interactor.stopScan()
    }

    // MARK: Private

    private func handleChange() {
        let scanning = interactor.currentState() == .poweredOn
        view?.render(rows: makeRows(), scanning: scanning)
    }

    private func makeRows() -> [DeviceRow] {
        interactor.discoveries().map { discovery in
            DeviceRow(
                name: discovery.peripheral.name ?? "(no name)",
                rssi: "RSSI: \(discovery.rssi)",
                advertisementSummary: Self.summarize(discovery.advertisementData)
            )
        }
    }
}
