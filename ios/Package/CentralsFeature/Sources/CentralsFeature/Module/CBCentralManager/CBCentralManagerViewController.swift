//
//  CBCentralManagerViewController.swift
//  CentralsFeature
//

import CBPlaygroundConsole
import UIKit

// MARK: - CBCentralManagerViewInput

/// Presenter から View への更新インターフェース
@MainActor
protocol CBCentralManagerViewInput: AnyObject {

    /// デバイス一覧とスキャン状態を反映する
    func render(rows: [DeviceRow], scanning: Bool)
}

// MARK: - CBCentralManagerViewController

final class CBCentralManagerViewController: UIViewController {

    // MARK: Properties

    var presenter: (any CBCentralManagerPresenterInput)!

    private var rows: [DeviceRow] = []

    // MARK: UI Components

    private let filterSwitch: UISwitch = {
        let s = UISwitch()
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let filterLabel: UILabel = {
        let l = UILabel()
        l.text = "Service UUID フィルタ (NUS)"
        l.font = .systemFont(ofSize: 14)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let duplicatesSwitch: UISwitch = {
        let s = UISwitch()
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let duplicatesLabel: UILabel = {
        let l = UILabel()
        l.text = "重複許可 (allowDuplicates)"
        l.font = .systemFont(ofSize: 14)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let startButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Start"
        config.baseBackgroundColor = .systemBlue
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let stopButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Stop"
        config.baseBackgroundColor = .systemRed
        let b = UIButton(configuration: config)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.isEnabled = false
        return b
    }()

    private let deviceTableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.translatesAutoresizingMaskIntoConstraints = false
        t.register(UITableViewCell.self, forCellReuseIdentifier: "DeviceCell")
        return t
    }()

    // MARK: Overridden Functions

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "CBCentralManager"
        view.backgroundColor = .systemBackground
        setupNavigationBar()
        setupLayout()
        setupActions()
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
        let logsVC = CBLogConsole.makeViewController()
        present(logsVC, animated: true)
    }

    // MARK: Private - Layout

    private func setupLayout() {
        let filterRow = makeRow(label: filterLabel, control: filterSwitch)
        let duplicatesRow = makeRow(label: duplicatesLabel, control: duplicatesSwitch)

        let buttonStack = UIStackView(arrangedSubviews: [startButton, stopButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let deviceHeader = UILabel()
        deviceHeader.text = "発見デバイス"
        deviceHeader.font = .systemFont(ofSize: 14, weight: .semibold)
        deviceHeader.translatesAutoresizingMaskIntoConstraints = false

        for item in [filterRow, duplicatesRow, buttonStack, deviceHeader, deviceTableView] {
            view.addSubview(item)
        }

        let margin: CGFloat = 16
        NSLayoutConstraint.activate([
            filterRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: margin),
            filterRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            filterRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            duplicatesRow.topAnchor.constraint(equalTo: filterRow.bottomAnchor, constant: 8),
            duplicatesRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            duplicatesRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            buttonStack.topAnchor.constraint(equalTo: duplicatesRow.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            buttonStack.heightAnchor.constraint(equalToConstant: 44),

            deviceHeader.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 16),
            deviceHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            deviceTableView.topAnchor.constraint(equalTo: deviceHeader.bottomAnchor, constant: 4),
            deviceTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            deviceTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            deviceTableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        deviceTableView.dataSource = self
    }

    private func makeRow(label: UILabel, control: UIView) -> UIView {
        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    // MARK: Private - Actions

    private func setupActions() {
        startButton.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(didTapStop), for: .touchUpInside)
    }

    @objc
    private func didTapStart() {
        presenter.onStartTapped(
            filterNUS: filterSwitch.isOn,
            allowDuplicates: duplicatesSwitch.isOn
        )
    }

    @objc
    private func didTapStop() {
        presenter.onStopTapped()
    }
}

// MARK: - CBCentralManagerViewInput

extension CBCentralManagerViewController: CBCentralManagerViewInput {
    func render(rows: [DeviceRow], scanning: Bool) {
        self.rows = rows
        deviceTableView.reloadData()
        startButton.isEnabled = !scanning
        stopButton.isEnabled = scanning
    }
}

// MARK: - UITableViewDataSource

extension CBCentralManagerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        let row = rows[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = row.name
        config.secondaryText = "\(row.rssi) | \(row.advertisementSummary)"
        cell.contentConfiguration = config
        return cell
    }
}
