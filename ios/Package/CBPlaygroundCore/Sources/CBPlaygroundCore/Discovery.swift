//
//  Discovery.swift
//  CBPlaygroundCore
//

import CoreBluetooth
import Foundation

/// BLE スキャンで周辺機器を 1 回発見したこと（`centralManager(_:didDiscover:advertisementData:rssi:)`
/// の 1 コールバック）を表すドメインモデル。
///
/// 役割は Interactor と Presenter の境界を渡る「生の発見結果」を運ぶこと。CBCentralManager が返す
/// 3 つの値を**整形せずそのまま**束ねる。こうすることで Interactor は UI を知らずに済み、表示用の整形
/// （名前の既定値・広告データの要約など）は Presenter の責務として分離できる。`advertisementData` を
/// 原文の辞書のまま保持するのは、「Core Bluetooth が実際に何を渡してくるか」を観察するという本リポジトリの
/// 目的に忠実であるため（整形して情報を落とさない）。単なる値の寄せ集めではなく、「1 回の発見」という
/// 意味のある単位を表す。
/// `@unchecked Sendable` の理由: Discovery は CBCentralManager(queue: .main) によって
/// Main Actor 上でのみ生成・消費される。CBPeripheral は Sendable 非準拠だが、
/// BLESession / Interactor / Presenter はすべて @MainActor に閉じており、
/// スレッドを跨いで渡すことがない。コンパイラが証明できない部分を実装者が保証する。
/// この `@unchecked` が必要なのは、`startScan` が `AsyncStream<Discovery>` を返し、
/// `AsyncStream` の Element が Sendable 準拠を要求するため（Element 型側の制約であり、
/// continuation のように `sending` で回避できない）。
/// 不変条件: 上記のとおり生成・consume はすべて @MainActor 上で完結しスレッドを跨がない。
/// 除去計画: defaultIsolation(MainActor) / NonisolatedNonsendingByDefault（approachable
/// concurrency）を導入した際に、BLESession 側の探索結果キャリアと併せて見直し・除去する。
public struct Discovery: @unchecked Sendable {

    // MARK: Properties

    /// 発見した周辺機器。識別子・名前のほか、接続すればサービス探索の起点になる。
    public let peripheral: CBPeripheral

    /// 広告パケットの内容（`CBAdvertisementData*` キーの辞書）。整形せず原文のまま保持する。
    public let advertisementData: [String: Any]

    /// 受信信号強度（dBm）。距離や電波状況の目安。
    public let rssi: NSNumber

    // MARK: Lifecycle

    public init(peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = rssi
    }
}
