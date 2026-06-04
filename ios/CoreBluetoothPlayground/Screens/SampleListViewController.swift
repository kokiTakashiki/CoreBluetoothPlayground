//
//  SampleListViewController.swift
//  CoreBluetoothPlayground
//

import UIKit

// MARK: - Sample

struct Sample {
    let number: String
    let title: String
    let make: () -> UIViewController
}

// MARK: - SampleListViewController

final class SampleListViewController: UITableViewController {

    // MARK: Properties

    private let samples: [Sample] = [
        Sample(
            number: "01",
            title: "Central Scan",
            make: { CentralScanViewController() }
        ),
    ]

    // MARK: Overridden Functions

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Core Bluetooth Playground"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SampleCell")
    }

    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        samples.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SampleCell", for: indexPath)
        let sample = samples[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = "\(sample.number) \(sample.title)"
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    // MARK: UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let sample = samples[indexPath.row]
        navigationController?.pushViewController(sample.make(), animated: true)
    }
}
