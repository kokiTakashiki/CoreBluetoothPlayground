# インターフェース対応表（網羅トラッカー）

全 Core Bluetooth インターフェースの網羅トラッカー。実装済みは CBCentralManager のみ。1 インターフェースずつ増分で全シンボルを網羅する。

| 区分 | シンボル | 扱い | 画面での内容 | 状態 |
| --- | --- | --- | --- | --- |
| Centrals | `CBCentral` | 操作 | iOS を Peripheral 役にし、購読してきた Central と maximumUpdateValueLength を観察 | 予定 |
| Centrals | `CBCentralManager` | 操作 | 状態・スキャン・接続/切断を操作して観察 | 実装済み（CentralsFeature / VIPER）（PR1） |
| Centrals | `CBCentralManagerDelegate` | 操作 | 各コールバックの発火を実機操作でログ表示 | 予定 |
| Peripherals | `CBPeripheral` | 操作 | 探索・read/write・RSSI 取得を操作して観察 | 実装済み（CentralsFeature / VIPER, PR2）|
| Peripherals | `CBPeripheralDelegate` | 操作 | 探索・読み書き完了コールバックをログ表示 | 実装済み（BLESession で bridge, PR2）|
| Peripherals | `CBPeripheralManager` | 操作 | ローカル GATT 公開・広告・updateValue を操作 | 予定 |
| Peripherals | `CBPeripheralManagerDelegate` | 操作 | 購読・読み書き要求コールバックをログ表示 | 予定 |
| Peripherals | `CBAttribute` | 説明 | 基底クラス。uuid プロパティと Service/Characteristic/Descriptor の継承関係を図解 | 予定 |
| Peripherals | `CBAttributePermissions` | 操作 | Mutable 定義時の権限を変え、読み書き可否を観察 | 予定 |
| Data Transfer | データ転送（解説記事） | 説明 | チャンク分割・MTU の要点を要約し CBCharacteristic 画面へ誘導 | 予定 |
| Services | `CBService` | 操作 | 探索結果のサービス階層を表示 | 実装済み（CBPeripheral VIPER の GATT ツリー表示, PR2）|
| Services | `CBMutableService` | 操作 | Peripheral 役でサービスを定義・公開 | 予定 |
| Services | `CBCharacteristic` | 操作 | read / write（with/without response）/ notify・indicate / properties / value | 予定 |
| Services | `CBMutableCharacteristic` | 操作 | Peripheral 役で特性を定義（properties・permissions） | 予定 |
| Services | `CBDescriptor` | 操作 | 記述子の探索・read/write | 予定 |
| Services | `CBMutableDescriptor` | 操作 | Peripheral 役で記述子を定義 | 予定 |
| Supporting | `CBManager` | 説明 | 基底クラス。state と authorization の意味を表示（実値は各 Manager 画面で） | 予定 |
| Supporting | `CBATTRequest` | 操作 | Peripheral 役で受信した read/write 要求の中身をログ | 予定 |
| Supporting | `CBPeer` | 説明 | 基底クラス。identifier の位置づけを図解 | 予定 |
| Supporting | `CBUUID` | 操作 | 文字列↔UUID 変換と定義済み UUID を表示 | 予定 |
| Errors | `CBError` / `CBError.Code` | 操作 | 接続失敗などを誘発しエラーコードを分類表示 | 予定 |
| Errors | `CBErrorDomain` | 説明 | 定数。エラー分類での役割を明記 | 予定 |
| Errors | `CBATTError` / `CBATTError.Code` | 操作 | 暗号化 Read 失敗などで ATT エラーを分類表示 | 予定 |
| Errors | `CBATTErrorDomain` | 説明 | 定数。ATT エラー分類での役割を明記 | 予定 |
| Variables | `CBUUIDCharacteristicObservationScheduleString` | 説明 | 定数 UUID。意味を明記し、対応記述子を持つ FW があれば操作観察へ拡張 | 予定 |
