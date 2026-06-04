//
//  CentralScanViewController.swift
//  CoreBluetoothPlayground
//

import UIKit

final class CentralScanViewController: UIViewController {

    // MARK: Properties

    private let model = CentralScanModel()

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

    private let logTextView: UITextView = {
        let t = UITextView()
        t.translatesAutoresizingMaskIntoConstraints = false
        t.isEditable = false
        t.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        t.backgroundColor = UIColor.systemGray6
        t.layer.cornerRadius = 6
        return t
    }()

    // MARK: Overridden Functions

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "01 Central Scan"
        view.backgroundColor = .systemBackground
        setupLayout()
        setupActions()
        setupModel()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        model.stopScan()
    }

    // MARK: Functions

    // MARK: Private - Layout

    private func setupLayout() {
        // Filter row
        let filterRow = makeRow(label: filterLabel, control: filterSwitch)
        let duplicatesRow = makeRow(label: duplicatesLabel, control: duplicatesSwitch)

        // Button row
        let buttonStack = UIStackView(arrangedSubviews: [startButton, stopButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // Device list header
        let deviceHeader = UILabel()
        deviceHeader.text = "発見デバイス"
        deviceHeader.font = .systemFont(ofSize: 14, weight: .semibold)
        deviceHeader.translatesAutoresizingMaskIntoConstraints = false

        // Log header
        let logHeader = UILabel()
        logHeader.text = "ログ"
        logHeader.font = .systemFont(ofSize: 14, weight: .semibold)
        logHeader.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        for item in [filterRow, duplicatesRow, buttonStack, deviceHeader, deviceTableView, logHeader, logTextView] {
            view.addSubview(item)
        }

        let margin: CGFloat = 16
        NSLayoutConstraint.activate([
            // Filter row
            filterRow.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: margin),
            filterRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            filterRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            // Duplicates row
            duplicatesRow.topAnchor.constraint(equalTo: filterRow.bottomAnchor, constant: 8),
            duplicatesRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            duplicatesRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),

            // Button stack
            buttonStack.topAnchor.constraint(equalTo: duplicatesRow.bottomAnchor, constant: 12),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            buttonStack.heightAnchor.constraint(equalToConstant: 44),

            // Device header
            deviceHeader.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 16),
            deviceHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            // Device table
            deviceTableView.topAnchor.constraint(equalTo: deviceHeader.bottomAnchor, constant: 4),
            deviceTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            deviceTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            deviceTableView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.28),

            // Log header
            logHeader.topAnchor.constraint(equalTo: deviceTableView.bottomAnchor, constant: 8),
            logHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            // Log text view
            logTextView.topAnchor.constraint(equalTo: logHeader.bottomAnchor, constant: 4),
            logTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            logTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            logTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -margin),
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
        model.startScan(
            filterNUS: filterSwitch.isOn,
            allowDuplicates: duplicatesSwitch.isOn
        )
        startButton.isEnabled = false
        stopButton.isEnabled = true
    }

    @objc
    private func didTapStop() {
        model.stopScan()
        startButton.isEnabled = true
        stopButton.isEnabled = false
    }

    // MARK: Private - Model

    private func setupModel() {
        model.onLog = { [weak self] message in
            DispatchQueue.main.async {
                self?.appendLog(message)
            }
        }
        model.onUpdate = { [weak self] in
            DispatchQueue.main.async {
                self?.deviceTableView.reloadData()
            }
        }
    }

    private func appendLog(_ message: String) {
        let current = logTextView.text ?? ""
        logTextView.text = current.isEmpty ? message : current + "\n" + message
        let range = NSRange(location: logTextView.text.count - 1, length: 0)
        logTextView.scrollRangeToVisible(range)
    }
}

// MARK: - UITableViewDataSource

extension CentralScanViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        model.discovered.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        let device = model.discovered[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = device.name ?? "(no name)"
        config.secondaryText = "RSSI: \(device.rssi) | \(device.id.uuidString.prefix(8))…"
        cell.contentConfiguration = config
        return cell
    }
}
