//
//  CBCentralManagerModel.swift
//  CoreBluetoothPlayground
//

import CoreBluetooth
import Foundation

// MARK: - DiscoveredPeripheral

struct DiscoveredPeripheral {

    // MARK: Properties

    let id: UUID
    let name: String?
    let rssi: NSNumber
    let advertisementSummary: String

    // MARK: Lifecycle

    init(peripheral: CBPeripheral, rssi: NSNumber, advertisementData: [String: Any]) {
        id = peripheral.identifier
        name = peripheral.name
        self.rssi = rssi
        advertisementSummary = DiscoveredPeripheral.summarize(advertisementData)
    }

    // MARK: Static Functions

    private static func summarize(_ data: [String: Any]) -> String {
        var parts: [String] = []
        if let serviceUUIDs = data[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            parts.append("services: \(serviceUUIDs.map(\.uuidString).joined(separator: ", "))")
        }
        if let localName = data[CBAdvertisementDataLocalNameKey] as? String {
            parts.append("localName: \(localName)")
        }
        if let txPower = data[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            parts.append("txPower: \(txPower)")
        }
        if let isConnectable = data[CBAdvertisementDataIsConnectable] as? NSNumber {
            parts.append("connectable: \(isConnectable.boolValue)")
        }
        return parts.isEmpty ? "(no data)" : parts.joined(separator: ", ")
    }
}

// MARK: - CBCentralManagerModel

final class CBCentralManagerModel: NSObject {

    // MARK: Properties

    var onLog: ((String) -> Void)?
    var onUpdate: (() -> Void)?
    private(set) var discovered: [DiscoveredPeripheral] = []

    private var centralManager: CBCentralManager!
    private var isFilteringNUS = false
    private var isAllowingDuplicates = false

    // MARK: Lifecycle

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: Functions

    func startScan(filterNUS: Bool, allowDuplicates: Bool) {
        guard centralManager.state == .poweredOn
        else {
            let reason = switch centralManager.state {
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
                "Bluetooth が利用できません (state=\(centralManager.state.rawValue))"
            }
            log("⚠️ スキャン開始できません: \(reason)")
            return
        }

        isFilteringNUS = filterNUS
        isAllowingDuplicates = allowDuplicates
        discovered = []
        onUpdate?()

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
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        onLog?("[\(timestamp)] \(message)")
    }
}

// MARK: - CBCentralManagerDelegate

extension CBCentralManagerModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let stateDesc = switch central.state {
        case .unknown:
            "unknown"
        case .resetting:
            "resetting"
        case .unsupported:
            "unsupported"
        case .unauthorized:
            "unauthorized"
        case .poweredOff:
            "poweredOff"
        case .poweredOn:
            "poweredOn"
        @unknown default:
            "unknown(\(central.state.rawValue))"
        }
        log("📡 状態変化: \(stateDesc)")
        onUpdate?()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let discovered = DiscoveredPeripheral(peripheral: peripheral, rssi: RSSI, advertisementData: advertisementData)
        let name = discovered.name ?? "(no name)"

        if let index = self.discovered.firstIndex(where: { $0.id == discovered.id }) {
            self.discovered[index] = discovered
            log(
                "↻ 更新: \(name) [\(discovered.id.uuidString.prefix(8))…] RSSI=\(RSSI) | \(discovered.advertisementSummary)"
            )
        }
        else {
            self.discovered.append(discovered)
            log(
                "✚ 発見: \(name) [\(discovered.id.uuidString.prefix(8))…] RSSI=\(RSSI) | \(discovered.advertisementSummary)"
            )
        }
        onUpdate?()
    }
}

// MARK: - DateFormatter + logFormatter

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}
