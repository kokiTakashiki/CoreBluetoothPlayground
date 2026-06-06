//
//  TopicListViewController.swift
//  CoreBluetoothPlayground
//

import CBPlaygroundConsole
import CentralsFeature
import UIKit

// MARK: - TopicListViewController

final class TopicListViewController: UITableViewController {

    // MARK: Properties

    private let topics = Topic.allCases

    // MARK: Overridden Functions

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Core Bluetooth Topics"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TopicCell")
        setupNavigationBar()
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        topics.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TopicCell", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        configuration.text = topics[indexPath.row].title
        cell.contentConfiguration = configuration
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // 画面生成は各 Router の責務。ここでは Router.assemble() を明示的に呼ぶ。
        let viewController: UIViewController =
            switch topics[indexPath.row] {
            case .cbCentralManager: CBCentralManagerRouter.assemble()
            }
        navigationController?.pushViewController(viewController, animated: true)
    }

    // MARK: Functions

    // MARK: Private

    private func setupNavigationBar() {
        let logsButton = UIBarButtonItem(
            title: "Logs",
            style: .plain,
            target: self,
            action: #selector(didTapLogs)
        )
        navigationItem.rightBarButtonItem = logsButton
    }

    @objc
    private func didTapLogs() {
        let logsViewController = CBLogConsole.makeViewController()
        navigationController?.pushViewController(logsViewController, animated: true)
    }

}
