//
//  CBCentralManagerAssembleTests.swift
//  CentralsFeatureTests
//

import CentralsFeature
import UIKit
import XCTest

@MainActor
final class CBCentralManagerAssembleTests: XCTestCase {

    func testAssembleReturnsViewController() {
        let vc = CBCentralManagerRouter.assemble()
        XCTAssertNotNil(vc)
        XCTAssertTrue(vc is UIViewController)
    }

    func testAssembledViewControllerType() {
        let vc = CBCentralManagerRouter.assemble()
        XCTAssertTrue(vc is UIViewController)
    }
}
