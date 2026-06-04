# 意思決定ログ

本文書は本リポジトリにおける設計上の判断を記録する単一の意思決定ログです。同じ論点を二度蒸し返さないよう、解決した選択はここに記録し、PR から参照します。

---

## 決定一覧

### D-001: 単一アプリ + サンプル一覧メニュー構成を採用する

**決定:** 複数ターゲット（サンプルごとにアプリを分ける）ではなく、1 つのアプリにサンプル一覧メニューを持つ構成とする。

**理由:** 署名・ビルドを一度で済ませ、実機転送を繰り返さなくて済む。各サンプルのフォルダ分離（`Samples/NN_Xxx/`）とサンプル間の相互参照禁止により、独立性は保てる。

**影響:** サンプルは `Samples/NN_Xxx/` に閉じ、共有コードは `Shared/` のみとする（サンプル間相互参照禁止）。

---

### D-002: UI フレームワークは UIKit を採用する

**決定:** SwiftUI ではなく UIKit（AppDelegate / SceneDelegate / UIViewController + Auto Layout）を採用する。

**理由:** テンプレート（iOSAppTemplate）が UIKit ベースであり、テンプレートの規約を踏襲する。Core Bluetooth の生のコールバックとの結線を明示的にコントロールしやすい。

---

### D-003: テンプレートは規約踏襲のみ、生成器は実行しない

**決定:** iOSAppTemplate（Genesis ベース）の生成物（`/tmp/gen-out/`）を参照・流用するが、本リポジトリで Genesis 生成器を再実行しない。

**理由:** Genesis 0.9.0 の非対話モードでは `usePersistence:false` / `usePreferences:false` オプションが無視される挙動が確認済み。また本リポジトリ固有の構造（`Samples/NN_Xxx/` / BLE 用途）は生成器の想定外である。テンプレートの知見（`.swiftformat` / `Mintfile` / `project.yml` の基本形）は直接適応する。

---

### D-004: コミットするのは spec + ソース + 設定ファイルのみ

**決定:** `.xcodeproj` / `.xcworkspace` / 生成 `Info.plist` / `DerivedData` / `.build` はコミットしない。

**理由:** `make ios-project`（`xcodegen generate`）でいつでも再生成できる。生成物をリポジトリに持つと差分ノイズになる。この除外はテンプレートの `.gitignore` 標準と一致している。

---

### D-005: firmware 環境はサブモジュール委譲

**決定:** nRF52840 DK / nRF Sniffer / NCS / Wireshark の環境構築・書き込み・検証は `kokiTakashiki/nrf52840-ble-debug-bootstrap` を git サブモジュールとして取り込み、その Makefile へ委譲する。PR4 で実装。

**理由:** 環境構築を自前で再実装するより、専用リポジトリの実装・CI・更新ライフサイクルに乗る方が保守コストが低い。本リポジトリが書くのは異常注入派生（`firmware/anomaly_*/`）のみとする。

---

### D-006: 対象プラットフォームは macOS / Apple Silicon 専用

**決定:** Linux 向け分岐を持たない。Apple Silicon Mac（arm64）専用とする。

**理由:** サブモジュール `nrf52840-ble-debug-bootstrap` が `check-os` で arm64 + Homebrew を要求する。iOS 開発も macOS 専用。uname による Linux 分岐は対象外であり持たない。

---

### D-007: Makefile の全ターゲット面を PR1 で確定する

**決定:** firmware 系ターゲットは PR1 で依存ガードとして定義し、PR4 で本体を埋める。iOS 系ターゲットは PR1 で実働させる。

**理由:** コマンド・インターフェースを最初に固定することで、後続フェーズが安定した呼び出し方を拠り所にできる（付録 A 参照）。インターフェースを後付けにするとフェーズごとに呼び出し方が揺れ、検証手順自体が不安定になる。

---

### D-008: GitHub Actions のサードパーティ Action はコミット SHA で固定する

**決定:** `.github/workflows/` で参照するサードパーティ Action は、`@v4` のようなミュータブルなタグではなく**フルコミット SHA**で固定し、バージョンをコメント併記する。例: `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1`。

**理由:** タグは上書き可能なため、タグ参照ではサプライチェーン攻撃（侵害された Action が同一タグで再配信される）を防げない。SHA は不変であり、レビュー済みの正確なコードに固定できる。

**運用:** 更新時は新バージョンの SHA を一次情報（公式リポジトリの `git ls-remote`）で解決し、コメントのバージョン表記も合わせて更新する。
