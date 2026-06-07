//
//  CBPeripheralRouter.swift
//  CentralsFeature
//

import CBPlaygroundCore
import UIKit

// MARK: - CBPeripheralRouterInput

/// CBPeripheral モジュールのルーター境界（今回は画面遷移なし）
@MainActor
protocol CBPeripheralRouterInput: AnyObject {}

// MARK: - CBPeripheralRouter

/// CBPeripheral VIPER モジュールの組み立てエントリ。
/// app shell は `assemble()` を呼んで得た UIViewController を表示するだけでよい。
@MainActor
public final class CBPeripheralRouter: CBPeripheralRouterInput {

    // MARK: Lifecycle

    private init() {}

    // MARK: Static Functions

    /// View / Presenter / Interactor / Router を組み上げて UIViewController を返す。
    /// BLESession を新規生成し Interactor に注入する。
    public static func assemble() -> UIViewController {
        let session = BLESession()
        let interactor = CBPeripheralInteractor(session: session)
        let presenter = CBPeripheralPresenter(interactor: interactor)
        let viewController = CBPeripheralViewController()
        viewController.presenter = presenter
        presenter.view = viewController
        return viewController
    }
}
