# インターフェース対応表

各サンプルが使用する Core Bluetooth クラス・メソッドと、確認できる挙動の対応表です。

| No | サンプル | 主な CB クラス | 主なメソッド / デリゲート | 確認できる挙動 | 状態 |
|----|----------|--------------|--------------------------|----------------|------|
| 01 | CentralScan | `CBCentralManager` | `scanForPeripherals(withServices:options:)` / `stopScan()` / `centralManagerDidUpdateState` / `didDiscover` | Service UUID フィルタの効き・allowDuplicates フラグの挙動・RSSI / アドバタイズデータの観察 | 実装済み（PR1） |
| 02 | ConnectDiscover | `CBCentralManager` / `CBPeripheral` | `connect(_:options:)` / `discoverServices(_:)` / `discoverCharacteristics(_:for:)` / `didConnect` / `didDiscoverServices` / `didDiscoverCharacteristics` | UUID 指定有無によるサービス・キャラクタリスティック探索の差、接続タイムアウト | 予定（PR2） |
| 03 | ReadWriteNotify | `CBPeripheral` | `readValue(for:)` / `writeValue(_:for:type:)` / `setNotifyValue(_:for:)` / `didUpdateValue` / `didWriteValue` | withResponse / withoutResponse の違い・通知の ON/OFF・MTU と書き込みサイズ制限 | 予定（PR2） |
| 04 | Security | `CBPeripheral` / `CBCentralManager` | 暗号化要求キャラへの `readValue` / `didDisconnectPeripheral` / `CBATTError` 分類 | ペアリング起動タイミング・暗号化失敗時のエラー分類・強制切断と再接続 | 予定（PR3） |
| 05 | PeripheralRole | `CBPeripheralManager` | `add(_:)` / `startAdvertising(_:)` / `didReceiveReadRequest` / `didReceiveWriteRequests` / `updateValue(_:for:onSubscribedCentrals:)` | GATT サーバ構築・Central からの読み書き受信・Notify による値プッシュ | 予定（PR3） |

## 01 CentralScan — 詳細

### 使用する CB API

```swift
// スキャン開始（フィルタあり）
centralManager.scanForPeripherals(
    withServices: [BLEConstants.nusService],
    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
)

// スキャン停止
centralManager.stopScan()
```

### デリゲートコールバック

| コールバック | タイミング | 確認できること |
|-------------|-----------|---------------|
| `centralManagerDidUpdateState` | Bluetooth 状態変化時 | poweredOn になるまでスキャン不可 |
| `didDiscover(_:advertisementData:rssi:)` | デバイス発見時 | アドバタイズデータ構造・RSSI 変化・重複制御 |

### 操作と観察ポイント

1. **フィルタなし vs NUS フィルタあり**: 周囲の全デバイスが見えるか、NUS サービスを広告するデバイスだけ見えるかを比較できる
2. **allowDuplicates ON/OFF**: ON のとき同一デバイスが RSSI 更新のたびに `didDiscover` を呼ぶ様子、OFF のとき 1 回しか呼ばれない様子を確認できる
