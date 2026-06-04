# CoreBluetoothPlayground

Core Bluetooth フレームワークの挙動を単独で確認するための iOS サンプルコード集リポジトリです。

## 目的

本番アプリの構築ではなく、Core Bluetooth の各 API が**どのように振る舞うか**を実機で直接確認することを目的としています。Central 役の iOS 実機と、Peripheral 役の nRF52840 開発キット、そして USB ドングル + Wireshark による空中パケット観測の三者で検証を成立させます。

## サンプル索引

| No | タイトル | 主な確認内容 | 状態 |
|----|----------|-------------|------|
| 01 | Central Scan | `scanForPeripherals` / フィルタ / 重複制御 | 実装済み |
| 02 | Connect & Discover | `connect` / `discoverServices` / `discoverCharacteristics` | 予定 (PR2) |
| 03 | Read / Write / Notify | `readValue` / `writeValue` / `setNotifyValue` | 予定 (PR2) |
| 04 | Security | 暗号化要求 / ペアリング / `CBATTError` | 予定 (PR3) |
| 05 | Peripheral Role | `CBPeripheralManager` / `startAdvertising` / GATT サーバ構築 | 予定 (PR3) |

詳細は [docs/interface-mapping.md](docs/interface-mapping.md) を参照してください。

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
- **iOS**: iOS 17.0 以降（実機）
- **ファームウェア**: nRF52840 開発キット（PR4 で追加）
- **観測**: nRF52840 USB ドングル + Wireshark（PR4 で追加）

> firmware および観測系の環境構築は `make setup` がサブモジュール `nrf52840-ble-debug-bootstrap` へ委譲します。初回は NCS の数 GB ダウンロードを伴います（PR4 で追加）。

## ドキュメント

- [docs/DECISIONS.md](docs/DECISIONS.md) — 意思決定ログ
- [docs/interface-mapping.md](docs/interface-mapping.md) — サンプル ↔ CB クラス対応表
- [docs/README.md](docs/README.md) — ドキュメント索引

## ライセンス

MIT
