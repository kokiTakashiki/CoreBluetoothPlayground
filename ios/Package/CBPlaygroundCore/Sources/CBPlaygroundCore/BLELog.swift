//
//  BLELog.swift
//  CBPlaygroundCore
//

import Pulse

/// Core Bluetooth の挙動ログを Pulse の LoggerStore に記録する薄い facade。
/// label にインターフェース名（例 "CBCentralManager"）を入れ、ConsoleView でラベル絞り込みできるようにする。
public enum BLELog {
    public static func log(_ label: String, _ message: String, level: LoggerStore.Level = .debug) {
        LoggerStore.shared.storeMessage(label: label, level: level, message: message)
    }
}
