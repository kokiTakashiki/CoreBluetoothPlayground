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
        let viewController = CBCentralManagerRouter.assemble()
        XCTAssertNotNil(viewController)
        XCTAssertTrue(viewController is UIViewController)
    }

    func testAssembledViewControllerType() {
        let viewController = CBCentralManagerRouter.assemble()
        XCTAssertTrue(viewController is UIViewController)
    }
}
