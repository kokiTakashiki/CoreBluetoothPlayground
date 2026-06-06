//
//  TopicListViewController.swift
//  CoreBluetoothPlayground
//

import CentralsFeature
import UIKit

// MARK: - Topic

/// 一覧メニューに並ぶ Core Bluetooth トピック（各クラス）の識別。
/// 表示名だけを持つ純粋なデータで、画面生成は持たない（生成は各 Router の責務）。
/// トピックを増やすときは case を足すだけでよく、遷移先の網羅は `didSelectRowAt` の switch でコンパイラが強制する。
enum Topic: CaseIterable {

    case cbCentralManager

    // MARK: Computed Properties

    var title: String {
        switch self {
        case .cbCentralManager: "CBCentralManager"
        }
    }
}

// MARK: - TopicListViewController

final class TopicListViewController: UITableViewController {

    // MARK: Properties

    private let topics = Topic.allCases

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
        // 画面生成は各 Router の責務。ここでは Router.assemble() を明示的に呼ぶ。
        let viewController: UIViewController =
            switch topics[indexPath.row] {
            case .cbCentralManager: CBCentralManagerRouter.assemble()
            }
        navigationController?.pushViewController(viewController, animated: true)
    }
}
