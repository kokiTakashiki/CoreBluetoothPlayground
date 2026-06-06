//
//  Discovery.swift
//  CBPlaygroundCore
//

import CoreBluetooth
import Foundation

/// 1 回の didDiscover を表す Entity。UI 結合の整形はせず生データを保持する。
public struct Discovery {

    // MARK: Properties

    public let peripheral: CBPeripheral
    public let advertisementData: [String: Any]
    public let rssi: NSNumber

    // MARK: Lifecycle

    public init(peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = rssi
    }
}
