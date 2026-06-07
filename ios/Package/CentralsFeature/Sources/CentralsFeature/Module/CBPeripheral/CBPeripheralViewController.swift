//
//  CBPeripheralViewController.swift
//  CentralsFeature
//

import CBPlaygroundConsole
import UIKit

// MARK: - CBPeripheralViewController

final class CBPeripheralViewController: UIViewController {

    // MARK: Nested Types

    // MARK: Display state

    private enum DisplayMode {
        case discoveries([PeripheralRow])
        case tree([GATTServiceSection])
    }

    // MARK: Properties

    var presenter: (any CBPeripheralPresenterInput)!

    private var displayMode: DisplayMode = .discoveries([])
    private var currentState: CBPeripheralPresenterState = .disconnected

    // MARK: UI Components

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "切断中"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let scanButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Scan"
        configuration.baseBackgroundColor = .systemBlue
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let stopScanButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Stop"
        configuration.baseBackgroundColor = .systemOrange
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        return button
    }()

    private let disconnectButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Disconnect"
        configuration.baseBackgroundColor = .systemRed
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isEnabled = false
        return button
    }()

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PeripheralCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "GATTCell")
        return tableView
    }()

    // MARK: Overridden Functions

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CBPeripheral"
        view.backgroundColor = .systemBackground
        setupNavigationBar()
        setupLayout()
        setupActions()
        tableView.dataSource = self
        tableView.delegate = self
        presenter.onViewReady()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        presenter.onViewDidDisappear()
    }

    // MARK: Functions

    // MARK: Private - Navigation

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
        present(logsViewController, animated: true)
    }

    // MARK: Private - Layout

    private func setupLayout() {
        let buttonStack = UIStackView(arrangedSubviews: [scanButton, stopScanButton, disconnectButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        for subview in [statusLabel, buttonStack, tableView] {
            view.addSubview(subview)
        }

        let margin: CGFloat = 16
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: margin),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            buttonStack.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            buttonStack.heightAnchor.constraint(equalToConstant: 44),

            tableView.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    // MARK: Private - Actions

    private func setupActions() {
        scanButton.addTarget(self, action: #selector(didTapScan), for: .touchUpInside)
        stopScanButton.addTarget(self, action: #selector(didTapStopScan), for: .touchUpInside)
        disconnectButton.addTarget(self, action: #selector(didTapDisconnect), for: .touchUpInside)
    }

    @objc
    private func didTapScan() {
        presenter.onScanTapped()
    }

    @objc
    private func didTapStopScan() {
        presenter.onStopScanTapped()
    }

    @objc
    private func didTapDisconnect() {
        presenter.onDisconnectTapped()
    }

    // MARK: Private - State helpers

    private func updateButtonStates() {
        switch currentState {
        case .scanning:
            scanButton.isEnabled = false
            stopScanButton.isEnabled = true
            disconnectButton.isEnabled = false
        case .discovered:
            scanButton.isEnabled = false
            stopScanButton.isEnabled = true
            disconnectButton.isEnabled = false
        case .connecting, .discovering:
            scanButton.isEnabled = false
            stopScanButton.isEnabled = false
            disconnectButton.isEnabled = false
        case .tree:
            scanButton.isEnabled = false
            stopScanButton.isEnabled = false
            disconnectButton.isEnabled = true
        case .disconnected, .failed:
            scanButton.isEnabled = true
            stopScanButton.isEnabled = false
            disconnectButton.isEnabled = false
        }
    }

    private func statusText(for state: CBPeripheralPresenterState) -> String {
        switch state {
        case .scanning: "スキャン中…"
        case .discovered: "デバイスが見つかりました（タップして接続）"
        case .connecting: "接続中…"
        case .discovering: "GATT 探索中…"
        case .tree: "探索完了"
        case .disconnected: "切断中"
        case let .failed(message): "エラー: \(message)"
        }
    }
}

// MARK: - CBPeripheralViewInput

extension CBPeripheralViewController: CBPeripheralViewInput {
    func renderDiscoveries(rows: [PeripheralRow], state: CBPeripheralPresenterState) {
        currentState = state
        displayMode = .discoveries(rows)
        statusLabel.text = statusText(for: state)
        updateButtonStates()
        tableView.reloadData()
    }

    func renderTree(sections: [GATTServiceSection], state: CBPeripheralPresenterState) {
        currentState = state
        displayMode = .tree(sections)
        statusLabel.text = statusText(for: state)
        updateButtonStates()
        tableView.reloadData()
    }

    func renderStatus(_ state: CBPeripheralPresenterState) {
        currentState = state
        statusLabel.text = statusText(for: state)
        updateButtonStates()
    }
}

// MARK: - UITableViewDataSource

extension CBPeripheralViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        switch displayMode {
        case .discoveries:
            1
        case let .tree(sections):
            sections.count
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch displayMode {
        case let .discoveries(rows):
            rows.count
        case let .tree(sections):
            sections[section].characteristics.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch displayMode {
        case .discoveries:
            return "発見デバイス"
        case let .tree(sections):
            let serviceSection = sections[section]
            let primaryLabel = serviceSection.isPrimary ? "Primary" : "Secondary"
            return "Service: \(serviceSection.serviceUUID) [\(primaryLabel)]"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch displayMode {
        case let .discoveries(rows):
            let cell = tableView.dequeueReusableCell(withIdentifier: "PeripheralCell", for: indexPath)
            let row = rows[indexPath.row]
            var configuration = cell.defaultContentConfiguration()
            configuration.text = row.name
            configuration.secondaryText = "\(row.rssi) | \(row.identifier)"
            cell.contentConfiguration = configuration
            cell.accessoryType = .disclosureIndicator
            return cell
        case let .tree(sections):
            let cell = tableView.dequeueReusableCell(withIdentifier: "GATTCell", for: indexPath)
            let characteristicRow = sections[indexPath.section].characteristics[indexPath.row]
            var configuration = cell.defaultContentConfiguration()
            configuration.text = "Characteristic: \(characteristicRow.characteristicUUID)"
            let descriptorSummary = if characteristicRow.descriptors.isEmpty {
                // 記述子なし（正常: すべてのキャラクタリスティックに記述子があるとは限らない）
                "descriptors: none"
            }
            else {
                "descriptors: \(characteristicRow.descriptors.map(\.descriptorUUID).joined(separator: ", "))"
            }
            configuration.secondaryText = "\(characteristicRow.propertiesSummary) | \(descriptorSummary)"
            cell.contentConfiguration = configuration
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension CBPeripheralViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch displayMode {
        case .discoveries:
            presenter.onPeripheralSelected(at: indexPath.row)
        case .tree:
            // GATT ツリー表示中は行選択で何もしない（read/write は CBCharacteristic 増分で実装）
            break
        }
    }
}
