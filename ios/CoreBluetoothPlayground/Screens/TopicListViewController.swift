//
//  TopicListViewController.swift
//  CoreBluetoothPlayground
//

import CBPlaygroundCore
import CentralsFeature
import UIKit

// MARK: - TopicListViewController

final class TopicListViewController: UITableViewController {

    // MARK: Properties

    /// メニューに並べる Core Bluetooth トピック（各クラス）。
    /// 各モジュールが `Topic` に準拠し、表示名と画面生成を自分で持つ。
    private let topics: [any Topic.Type] = [
        CBCentralManagerRouter.self,
    ]

    // MARK: Overridden Functions

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Core Bluetooth Topics"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TopicCell")
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        topics.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TopicCell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = topics[indexPath.row].title
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(topics[indexPath.row].makeViewController(), animated: true)
    }
}
