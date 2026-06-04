//
//  BLEConstants.swift
//  CoreBluetoothPlayground
//

import CoreBluetooth

/// Nordic UART Service (NUS) の UUID 定義
enum BLEConstants {

    // MARK: - NUS Service UUID

    /// Nordic UART Service (NUS) のサービス UUID
    static let nusService = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")

    // MARK: - NUS Characteristic UUIDs

    /// RX キャラクタリスティック UUID（Write: Central → Peripheral）
    static let nusRX = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")

    /// TX キャラクタリスティック UUID（Notify: Peripheral → Central）
    static let nusTX = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
}
