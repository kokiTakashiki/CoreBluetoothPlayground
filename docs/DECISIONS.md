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

---

### D-009: 単体テストを CI ゲートに含め、シミュレータは動的解決する

**決定:** `ios-test`（`xcodebuild test`）を CI の機械ゲートに含める（macos-15 + 最新安定 Xcode）。テスト実行先シミュレータは機種名をハードコードせず、`xcrun simctl list devices available` から利用可能な最新 iPhone を実行時に解決する。

**理由:** テストを書いても CI で実行しなければ将来の回帰を検知できない。機種名のハードコード（旧 `iPhone 17`）は実行環境によって存在せず非可搬であり、動的解決でどのマシン/CI でも通るようにする。

**運用:** 解決は Makefile の `ios-test` レシピ内のシェルで行い（`$(shell)` は使わない）、`make -n` のパース時には実行されないようにする。

---

### D-010: サンプルの分割単位を Core Bluetooth の公式インターフェース（クラス）に対応づける

**決定:** サンプルの分割単位を Core Bluetooth の公式クラス（インターフェース）に 1 対 1 で対応づける。全シンボルが専用画面を持ち、操作対象があれば操作で検証し、無ければ説明に留める。ディレクトリ名・型名は CB クラス名そのままをキーにする（例: `Samples/CBCentralManager/CBCentralManagerViewController.swift`）。

**理由:** Core Bluetooth はプロプライエタリで内部が見えず、各インターフェースの振る舞いを単位で観察したいから。View はインターフェース単位・実装は共通の二層とし、接続等の土台は共有セッション層 `Shared/BLESession` に集約する。これにより「あるクラスの挙動を見たいとき対応するサンプルが一意に定まる」状態を維持できる。

**影響:** `Samples/01_CentralScan/` → `Samples/CBCentralManager/`、`SampleListViewController` → `InterfaceListViewController`、`struct Sample` → `struct Interface`（フィールドは `symbol: String` と `make: () -> UIViewController`）、画面タイトルは「Core Bluetooth Interfaces」に変更。`docs/interface-mapping.md` は全インターフェース網羅トラッカーに更新。共有セッション層 `BLESession` は CBPeripheral 増分で初めて導入（今回は対象外）。

---

### D-011: deploymentTarget と SWIFT_VERSION を最新に固定する

**決定:** `ios/project.yml` の deploymentTarget を iOS 26.0、SWIFT_VERSION を 6.0（Swift 6 言語モード）に更新する。

**理由:** 本リポジトリは個人の総復習用であり、対象は最新の iOS 実機・Xcode（26 系）。最新の言語モードで Core Bluetooth の挙動を確認したい。Swift 6 の strict concurrency は将来の並行性バグを早期に検出する利点もある。

**影響:** Swift 6 言語モードでは、非 Sendable な `CBUUID` の静的格納定数（`static let`）が concurrency-safe でないと判定される。これに対し `Shared/BLEConstants` の各 UUID は計算プロパティ `static var { CBUUID(string:) }` とし、静的格納状態を持たせない（並行チェックの対象外）。CBUUID は不変で値比較されるため、都度生成しても CoreBluetooth から見た振る舞いは同一であり、`nonisolated(unsafe)` を避けられる。CI は macos-15 + 最新安定 Xcode（iOS 26 SDK / Swift 6）で build・test とも green を確認済み。

---

### D-012: 機能別 SwiftPM パッケージ（Apple カテゴリ単位）+ 複雑画面は VIPER を採用する

**決定:** 機能別 SwiftPM パッケージ（Apple カテゴリ単位）+ 複雑画面は VIPER（RoofWallPainterEdit 準拠）を採用する。CBCentralManager を初の VIPER モジュール化し `DiscoveredPeripheral` を廃止する。

**理由:** プロジェクトが大きくなる前提で依存を機能境界で分離し、Interactor が必要な範囲だけ公開・Presenter が表示 VM を作る形にして UI 結合 DTO を排する。`DiscoveredPeripheral`（名前・RSSI・広告データを UI 向けに整形した DTO）は Interactor に保持すべき情報を View 結合で束ねており、VIPER では Interactor が生の `Discovery` Entity を公開し、Presenter が `DeviceRow`（表示 VM）を組み立てる形にする。

**影響:** `ios/Package/CBPlaygroundCore`・`ios/Package/CentralsFeature` 新設。`BLEConstants` は `CBPlaygroundCore` へ移動（`public enum BLEConstants`）。`Discovery`（生データ Entity）を `CBPlaygroundCore` に追加。`CentralsFeature` に CBCentralManager VIPER 一式（InteractorInput / Presenter / ViewController / Router）と具象 Interactor `CBCentralScanInteractor` を配置。app shell（`InterfaceListViewController`）は `import CentralsFeature` し `CBCentralManagerRouter.assemble()` を呼ぶ。旧 `Samples/CBCentralManager/`・`Shared/BLEConstants.swift` を削除。`project.yml` に `packages:` セクション追加と app target に `CentralsFeature` 依存を追加。

---

### D-013: メニュー項目は `InterfaceModule` プロトコルで表す（`struct Interface` を廃止）

**決定:** app shell の一覧メニューが持つ「行」を、クロージャ詰めの値型 `struct Interface { symbol; make }` ではなく、`CBPlaygroundCore` の `protocol InterfaceModule`（`static var symbol` / `static func makeViewController()`）で表す。各モジュールの Router がこれに準拠し、app shell は `[any InterfaceModule.Type]` を並べるだけにする。D-010 で導入した `struct Interface` はこれに置き換える。

**理由:** Swift で "Interface" という値型名は protocol の概念と衝突して紛らわしく、中身（表示名＋生成クロージャ）が名前に伴わない割れ窓だった。protocol にすると表示名と生成口が各モジュール側（単一の真実）に移り、app shell からメタ情報のハードコードが消え、VIPER のモジュール境界とも筋が通る。

**影響:** `CBPlaygroundCore` に `InterfaceModule.swift` を追加。`CBCentralManagerRouter` を `InterfaceModule` に準拠（`symbol` / `makeViewController()`）。`InterfaceListViewController` は `struct Interface` を廃し `private let modules: [any InterfaceModule.Type]` を持つ。app target に `CBPlaygroundCore` 依存を明示追加。
