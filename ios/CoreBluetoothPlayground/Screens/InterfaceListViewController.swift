//
//  InterfaceListViewController.swift
//  CoreBluetoothPlayground
//

import CentralsFeature
import UIKit

// MARK: - Interface

struct Interface {
    let symbol: String
    let make: () -> UIViewController
}

// MARK: - InterfaceListViewController

final class InterfaceListViewController: UITableViewController {

    // MARK: Properties

    private let interfaces: [Interface] = [
        Interface(
            symbol: "CBCentralManager",
            make: { CBCentralManagerRouter.assemble() }
        ),
    ]

    // MARK: Overridden Functions

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Core Bluetooth Interfaces"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "InterfaceCell")
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        interfaces.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "InterfaceCell", for: indexPath)
        let interface = interfaces[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = interface.symbol
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let interface = interfaces[indexPath.row]
        navigationController?.pushViewController(interface.make(), animated: true)
    }
}
