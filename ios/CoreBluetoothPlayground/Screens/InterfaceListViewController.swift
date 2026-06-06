//
//  InterfaceListViewController.swift
//  CoreBluetoothPlayground
//

import CBPlaygroundCore
import CentralsFeature
import UIKit

// MARK: - InterfaceListViewController

final class InterfaceListViewController: UITableViewController {

    // MARK: Properties

    /// メニューに並べる Core Bluetooth インターフェースのモジュール。
    /// 各モジュールが `InterfaceModule` に準拠し、表示名と画面生成を自分で持つ。
    private let modules: [any InterfaceModule.Type] = [
        CBCentralManagerRouter.self,
    ]

    // MARK: Overridden Functions

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Core Bluetooth Interfaces"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "InterfaceCell")
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        modules.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "InterfaceCell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = modules[indexPath.row].symbol
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(modules[indexPath.row].makeViewController(), animated: true)
    }
}
