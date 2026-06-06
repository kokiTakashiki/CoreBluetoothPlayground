# CoreBluetoothPlayground

Core Bluetooth フレームワークの挙動を単独で確認するための iOS サンプルコード集リポジトリです。

## 目的

本番アプリの構築ではなく、Core Bluetooth の各 API が**どのように振る舞うか**を実機で直接確認することを目的としています。Central 役の iOS 実機と、Peripheral 役の nRF52840 開発キット、そして USB ドングル + Wireshark による空中パケット観測の三者で検証を成立させます。

## 構成

アプリ本体（app shell）と機能別 SwiftPM パッケージの組み合わせで構成します。

```
ios/
  CoreBluetoothPlayground/       app shell（InterfaceListViewController・起動処理）
  Package/
    CBPlaygroundCore/            共有コア（BLEConstants・Discovery Entity）
    CentralsFeature/             Centrals カテゴリ（CBCentralManager VIPER モジュール）
  project.yml                    XcodeGen スペック
```

app shell はインターフェース一覧メニュー（`InterfaceListViewController`）と起動処理だけを持ち、各機能パッケージに依存します。複雑な操作画面は VIPER（View / Presenter / Interactor / Router）で実装し、`Router.assemble()` を入口にしています。

## インターフェース索引

サンプルは Core Bluetooth の公式インターフェース（クラス）単位で管理します。全シンボルが専用画面を持ち、1 インターフェースずつ増分で網羅していきます。

| インターフェース | 主な確認内容 | 状態 |
|-----------------|-------------|------|
| `CBCentralManager` | 状態・スキャン・接続/切断を操作して観察 | 実装済み（CentralsFeature / VIPER）（PR1） |
| `CBPeripheral` | 探索・read/write・RSSI 取得を操作して観察 | 予定 |
| `CBCharacteristic` | read / write / notify・indicate / properties | 予定 |
| `CBDescriptor` | 記述子の探索・read/write | 予定 |
| `CBPeripheralManager` | ローカル GATT・広告・updateValue を操作 | 予定 |
| その他の全インターフェース | 順次追加 | 予定 |

全インターフェースの一覧と状態は [docs/interface-mapping.md](docs/interface-mapping.md) を参照してください。

## クイックスタート

```sh
# 利用可能なコマンドを確認
make help

# iOS ツール導入（mint bootstrap）
make setup

# プロジェクト生成とビルド（シミュレータ）
make ios-build

# 整形チェック
make ios-format-check

# 実装済みサンプル一覧
make list-samples
```

## 対象環境

- **Mac**: Apple Silicon Mac（arm64）+ macOS 14 以降
- **iOS**: iOS 26.0 以降（実機）
- **ファームウェア**: nRF52840 開発キット（PR4 で追加）
- **観測**: nRF52840 USB ドングル + Wireshark（PR4 で追加）

> firmware および観測系の環境構築は `make setup` がサブモジュール `nrf52840-ble-debug-bootstrap` へ委譲します。初回は NCS の数 GB ダウンロードを伴います（PR4 で追加）。

## ドキュメント

- [docs/DECISIONS.md](docs/DECISIONS.md) — 意思決定ログ
- [docs/interface-mapping.md](docs/interface-mapping.md) — サンプル ↔ CB クラス対応表
- [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) — 実装計画書
- [docs/README.md](docs/README.md) — ドキュメント索引

## ライセンス

MIT
