//
//  CBCentralManagerRouter.swift
//  CentralsFeature
//

import CBPlaygroundCore
import UIKit

// MARK: - CBCentralManagerRouterInput

/// CBCentralManager モジュールのルーター境界（今回は画面遷移なし）
@MainActor
protocol CBCentralManagerRouterInput: AnyObject {}

// MARK: - CBCentralManagerRouter

/// CBCentralManager VIPER モジュールの組み立てエントリ。
/// app shell は `assemble()` を呼んで得た UIViewController を表示するだけでよい。
@MainActor
public final class CBCentralManagerRouter: CBCentralManagerRouterInput {

    // MARK: Lifecycle

    private init() {}

    // MARK: Static Functions

    /// View / Presenter / Interactor / Router を組み上げて UIViewController を返す。
    public static func assemble() -> UIViewController {
        let interactor = CBCentralScanInteractor()
        let presenter = CBCentralManagerPresenter(interactor: interactor)
        let viewController = CBCentralManagerViewController()
        viewController.presenter = presenter
        presenter.view = viewController
        return viewController
    }
}

// MARK: - Topic

extension CBCentralManagerRouter: Topic {

    public static var title: String {
        "CBCentralManager"
    }

    public static func makeViewController() -> UIViewController {
        assemble()
    }
}
