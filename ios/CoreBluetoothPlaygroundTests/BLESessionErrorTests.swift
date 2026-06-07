//
//  BLESessionErrorTests.swift
//  CoreBluetoothPlaygroundTests
//

import CBPlaygroundCore
import XCTest

/// BLESessionError の定義が期待どおりであることを確認する純粋ロジックテスト。
/// CBCentralManager は実機 Bluetooth を要求するため、BLESession 自体のテストは除外し
/// エラー型の判定可能性のみを検証する。
final class BLESessionErrorTests: XCTestCase {

    func testNotPoweredOnIsError() {
        let error: BLESessionError = .notPoweredOn
        // Error プロトコルに準拠していること
        let asError: Error = error
        XCTAssertNotNil(asError)
    }

    func testConnectionFailedWrapsUnderlyingError() {
        let underlying = NSError(domain: "TestDomain", code: 42)
        let error = BLESessionError.connectionFailed(underlying)
        // パターンマッチで underlying を取り出せること
        if case let .connectionFailed(inner) = error {
            XCTAssertEqual((inner as NSError?)?.code, 42)
        }
        else {
            XCTFail("connectionFailed のパターンマッチに失敗")
        }
    }

    func testConnectionFailedWithNilUnderlyingError() {
        let error = BLESessionError.connectionFailed(nil)
        if case let .connectionFailed(inner) = error {
            XCTAssertNil(inner)
        }
        else {
            XCTFail("connectionFailed(nil) のパターンマッチに失敗")
        }
    }

    func testDisconnectedWrapsUnderlyingError() {
        let underlying = NSError(domain: "TestDomain", code: 7)
        let error = BLESessionError.disconnected(underlying)
        if case let .disconnected(inner) = error {
            XCTAssertEqual((inner as NSError?)?.code, 7)
        }
        else {
            XCTFail("disconnected のパターンマッチに失敗")
        }
    }

    func testAlreadyInProgressIsError() {
        let error: BLESessionError = .alreadyInProgress
        let asError: Error = error
        XCTAssertNotNil(asError)
    }

    func testAllCasesAreDistinct() {
        // notPoweredOn と alreadyInProgress がそれぞれ識別されること
        let notPoweredOn = BLESessionError.notPoweredOn
        let alreadyInProgress = BLESessionError.alreadyInProgress
        if case .notPoweredOn = notPoweredOn {
            // OK
        }
        else {
            XCTFail("notPoweredOn のパターンマッチに失敗")
        }
        if case .alreadyInProgress = alreadyInProgress {
            // OK
        }
        else {
            XCTFail("alreadyInProgress のパターンマッチに失敗")
        }
    }
}
