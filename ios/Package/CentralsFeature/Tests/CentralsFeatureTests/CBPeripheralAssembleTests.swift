//
//  CBPeripheralAssembleTests.swift
//  CentralsFeatureTests
//

import CentralsFeature
import UIKit
import XCTest

@MainActor
final class CBPeripheralAssembleTests: XCTestCase {

    func testAssembleReturnsViewController() {
        let viewController = CBPeripheralRouter.assemble()
        XCTAssertNotNil(viewController)
        XCTAssertTrue(viewController is UIViewController)
    }
}
