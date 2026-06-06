//
//  CBCentralManagerModelTests.swift
//  CoreBluetoothPlaygroundTests
//

import CBPlaygroundCore
import XCTest

final class CBCentralManagerModelTests: XCTestCase {

    func testNUSServiceUUID() {
        // Nordic UART Service の UUID が仕様どおりであること（CBPlaygroundCore 公開 API のスモーク）
        XCTAssertEqual(
            BLEConstants.nusService.uuidString.uppercased(),
            "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
        )
    }

    func testNUSCharacteristicUUIDs() {
        // RX / TX の UUID が仕様どおりであること
        XCTAssertEqual(
            BLEConstants.nusRX.uuidString.uppercased(),
            "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
        )
        XCTAssertEqual(
            BLEConstants.nusTX.uuidString.uppercased(),
            "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
        )
    }
}
