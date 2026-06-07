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

### D-008: サードパーティ依存はコミット SHA で固定する（GitHub Actions と SwiftPM）

**決定:** 外部から取り込む依存は、ミュータブルなタグではなく**フルコミット SHA**で固定し、バージョンをコメント併記する。
- GitHub Actions: 例 `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1`。
- SwiftPM リモート依存: `.package(url:, exact:)` ではなく `.package(url:, revision: "<sha>") // <version>` を使う。例 `.package(url: "https://github.com/kean/Pulse", revision: "a4e5bc2b0439552d4ff5fc9667c389be6ef5bd52") // 5.2.2`（RoofWallPainterEdit も同方式）。

**理由:** タグは上書き可能なため、タグ参照ではサプライチェーン攻撃（侵害された成果物が同一タグで再配信される）を防げない。SHA は不変であり、レビュー済みの正確なコードに固定できる。

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

### D-013: メニュー項目は純データ `enum Topic` で表す（`struct Interface` を改名・整理）

**決定:** app shell の一覧メニューの「行」を、app shell ローカルの純データ `enum Topic: CaseIterable`（`title` だけを持つ）で表す。画面生成は各 Router の責務とし、`TopicListViewController.didSelectRowAt` の `switch` で `CBCentralManagerRouter.assemble()` を**明示的に**呼ぶ。D-010 で導入した `struct Interface` はこの `Topic` に置き換える。

**理由:** 割れ窓の正体は「struct であること」ではなく「`Interface` という型名」だった（"Interface" は protocol／UI／一般語と衝突）。さらに、メニュー行に VC 生成ファクトリ（クロージャ）を持たせると「Topic が画面を生成できる」という責務の混線が起き、`@MainActor () -> UIViewController` を struct に格納する奇抜なスタイルにもなる。そこで **Topic は純データ（どのトピックか＋表示名）に徹し**、画面生成は呼び出し側で `Router.assemble()` を明示する形にした。可読性が高く、将来 Topic の扱いに迷わない。`enum` + `CaseIterable` によりトピック追加は case を足すだけで、遷移先の網羅を `switch` がコンパイル時に強制する。

**経緯（補足）:** `struct Interface`（クロージャ詰め）→ `protocol Topic`（"Interface=protocol" の名前由来の誤解）→ `struct Topic`（クロージャ格納が奇抜）と回り道したのち、最終的に「VC 生成を持たない純データ enum + Router.assemble() 明示呼び出し」へ収束した。

**影響:** `CBPlaygroundCore` の `Topic.swift` は削除（Core には置かない）。`enum Topic` は app shell の `TopicListViewController.swift` に internal で置く。`CBCentralManagerRouter` は `assemble()` のみ（protocol 準拠なし）。一覧画面は `InterfaceListViewController` → `TopicListViewController` に改名、画面タイトルは "Core Bluetooth Topics"。app target の `CBPlaygroundCore` 依存は外す（app shell は Router のため `CentralsFeature` だけ参照。テストターゲットは BLEConstants 検証で `CBPlaygroundCore` 依存を維持）。将来 Feature 側がトピックを自前公開する形にするなら、その時に共有型を再導入する。

---

### D-014: ログ管理と閲覧 UI に Pulse（5.2.2）を採用する

**決定:** ログ管理と閲覧 UI に [Pulse](https://github.com/kean/Pulse) 5.2.2 を採用する。Core に `BLELog` facade（`CBPlaygroundCore`）を置き、共有 UI パッケージ `CBPlaygroundConsole` に `ConsoleView` を UIKit ホストする `CBLogConsole` を配置する。Interactor の `onLog: ((String) -> Void)?` 配線（Interactor → Presenter → View のログ送出と UITextView）を全層撤去する。

**理由:**
- 実機内でログを閲覧できる UI が Pulse の `ConsoleView`（PulseUI）として標準提供されており、自前のログビューア（UITextView）が不要になる。
- `label` パラメータでインターフェース別（例: "CBCentralManager"）にフィルタリングできる（ConsoleView の UI からラベル絞り込みが可能）。
- Interactor の `onLog` クロージャ → Presenter の `logBuffer` / `handleLog` → View の `appendLog` という配線が消え、各層の責務境界が締まる。ログは `BLELog.log(_:_:level:)` → `LoggerStore.shared.storeMessage(...)` の直通になる。

**ConsoleView のラベル初期フィルタについて:** `ConsoleView` の公開 init（`init(store:mode:delegate:)`）にはラベルを初期フィルタとして渡す引数が存在しない（`ConsoleEnvironment.init` は `package` 修飾で外部公開されていない）。そのため `CBLogConsole.makeViewController(label:)` は引数を受け取るが現時点では全件表示とし、ユーザーは ConsoleView のフィルタ UI でラベルを絞り込む。

**影響:**
- `CBPlaygroundCore/Package.swift`: Pulse 5.2.2 依存追加、target に `.product(name: "Pulse", ...)` 追加。
- `CBPlaygroundCore/Sources/CBPlaygroundCore/BLELog.swift`: 新規作成（Pulse facade）。
- `ios/Package/CBPlaygroundConsole/`: 新規パッケージ（PulseUI 依存、`CBLogConsole` を公開）。
- `CentralsFeature/Package.swift`: `CBPlaygroundConsole` 依存追加。
- `CBCentralManagerInteractorInput`: `onLog` プロパティ削除。
- `CBCentralScanInteractor`: `onLog` プロパティ削除、`log(_:)` を `BLELog.log(...)` 呼び出しに変更、`DateFormatter+logFormatter` 削除。
- `CBCentralManagerPresenter`: `logBuffer`・`handleLog`・`view?.appendLog(...)` 削除。
- `CBCentralManagerViewController` / `CBCentralManagerViewInput`: `logTextView`・`appendLog(_:)` 削除、ナビバー右に「Logs」ボタン追加（`CBLogConsole.makeViewController(label: "CBCentralManager")` を present）。
- `TopicListViewController`: `CBPlaygroundConsole` import、ナビバー右に「Logs」ボタン追加（全件表示）。
- `ios/project.yml`: `CBPlaygroundConsole` をローカルパッケージに追加、app target 依存に追加。

---

### D-015: ログ取得を `@BLELog` body マクロに一本化し、ログの取り方を規律で縛る

**決定:** ログ取得を Swift Macro（`@attached(body)` の `@BLELog`）へ一本化する。各型に重複していた `private static let logLabel` と `private func log(_:)`、および散在する `BLELog.log(...)` 直書きを廃止し、ログは `@BLELog` を付けたメソッドの脱出（exit）でちょうど 1 行だけ出す形に集約する。マクロ実装は新設の SwiftPM パッケージ `CBPlaygroundLogging`（`.macro` 実装ターゲット `CBPlaygroundLoggingMacros` + 公開ライブラリ `CBPlaygroundLogging`）に置く。

**命名方針（パッケージ名はドメインで名乗る）:** パッケージ名は「Swift Macros を集めたもの」のような実装手段ではなく、提供するドメイン（ログ機能）で名乗る。そのため公開パッケージ／公開ライブラリは `CBPlaygroundLogging` とし、実装手段の Swift Macros は内部ターゲット名 `CBPlaygroundLoggingMacros`（「Logging パッケージのマクロ実装」と読める形）へ追いやる。マクロ名そのもの（`BLELog` / `BLELogLevel` / `BLELogRuntime`）は `BLE` 接頭辞でドメインが十分明示できているため改名しない。

**理由（最重要 = 設計思想）:** 狙いはボイラープレート削減ではなく、ログの取り方を規律で縛ること。ログは簡単に取れるからこそ取りすぎ・取らなすぎが起きる。そこでマクロの不自由さを使い「1 メソッド = ログ 1 行（exit で 1 回だけ）」を強制する。途中経過のログは書けないため、1 行で説明しきれないメソッドは責務過多のシグナルとみなせる。これにより、旧実装で分岐ごとに別々のログを出していた箇所（`startScan` の開始可否、`didDiscover` の更新/追加）は、結末を表す文字列を返すメソッドへ分割し、その単一の戻り値を結末として記録する形へ自然に矯正される。

**マクロ展開仕様（既定 = 結果捕捉版）:** 元の本文を入れ子関数 `__blelogBody` へ退避し、その呼び出し結果を捕捉して exit で 1 行ログする。`throws` のときは do/catch で包み、成功・失敗の双方を 1 行にする。`async` / `throws` / 戻り値あり・なし・`Void` のすべてで一貫した展開になる（Void でも非 throws でも同形の「成功」ログを出す）。

- メッセージ規約: `message` には動作を 1 行で表す固定文（補間なし）を渡し、展開時に末尾へ結末を自動付与する。成功・戻り値あり = `<message> → 成功(<戻り値>)`、成功・Void = `<message> → 成功`、失敗 = `<message> → 失敗(<error>)`（失敗は常に `.error`）。
- `level` 省略時は `.info`。`BLELogLevel`（.debug/.info/.warning/.error）を新設し Pulse の `LoggerStore.Level` へマッピングする。旧来の絵文字接頭辞（🔍 ⏹ ↻ ✚ ⚠️ など）は廃止しレベル表示へ一本化する。
- `label` 省略時は囲っている型名から自動採番する。BodyMacro の `expansion` で `context.lexicalContext` を内側から外側へ辿り、最初に見つかった型宣言（class / struct / enum / actor、extension は拡張対象型）の名前を label とする。明示指定も可能で、指定時はそれを優先する。型名が辿れない場合のフォールバックは "BLELog"。
- **label の運用規約:** 本リポジトリの観察軸は Core Bluetooth のインターフェース名（"CBCentralManager"、"CBPeripheral"、"CBCharacteristic" …）であり、ConsoleView の Labels 絞り込みもこの軸で行う。実装者の型名（"CBCentralScanInteractor" 等）は採用しない。したがって Interactor 等の実装側では **インターフェース名を `label:` で明示する**ことを規約とし、自動採番は型名そのものが観察対象になっているとき（例: 後続増分で `BLESession` のように、型名と観察対象が一致するクラス内）にのみ用いる。

**単純 defer 版との比較（採否の根拠）:** 「単純 defer 版（引数のみ参照・軽量）」は結末（戻り値・成功失敗）をログに残せず、観察対象（Core Bluetooth が何を返したか）を取りこぼす。本リポジトリの目的は挙動観察であり結末こそが重要なため、重さを承知で「結果捕捉版」を既定採用する。入れ子関数方式により全シグネチャで破綻なく展開でき、特定シグネチャの defer 版フォールバックは不要だった（事実に判定させた結果、フォールバック分岐は設けていない）。

**縦切りで確認した統合リスク:**
- **XcodeGen × macro plugin:** ローカル SwiftPM パッケージの `.macro` ターゲットは Xcode が SPM として解決し、macro プラグインはホスト（macOS）向けにビルドされる。
- **`xcodebuild -sdk` の落とし穴（重要）:** `make ios-build` が付けていた `-sdk iphonesimulator` を指定すると、macro プラグインまでシミュレータ SDK でビルドされ、ホストで実行できず「external macro implementation … produced malformed response」となる。`-sdk` を外し `-destination 'generic/platform=iOS Simulator'` のみにすると、プラグインはホスト（macOS, platform 1）、アプリ本体はシミュレータ向けに正しく分かれてビルドされ解決する。
- **swift-syntax のビルド時間増:** swift-syntax 602.0.0 のビルドを伴うぶん初回ビルドが重くなるのは織り込み済み。

**影響:**
- `ios/Package/CBPlaygroundLogging/`: 新規パッケージ。`.macro` ターゲット `CBPlaygroundLoggingMacros`（`BLELogMacro` / `BLELogArguments` / `BLELogDiagnostic` / `Plugin`）と公開ライブラリ `CBPlaygroundLogging`（`@BLELog` 宣言・`BLELogLevel`・ランタイム facade `BLELogRuntime`）。swift-syntax は D-008 準拠でコミット SHA `4799286537280063c85a32f09884cfbca301b1a1`（602.0.0）に固定。Pulse は既存と同一 SHA。
- `CBPlaygroundCore`: 旧 `BLELog.swift`（Pulse facade）を削除。唯一の Pulse 利用者だったため `CBPlaygroundCore` の Pulse 依存も撤去。ログ facade は `CBPlaygroundLogging` の `BLELogRuntime` へ移管（D-014 の `BLELog.log(...)` 直通は `@BLELog` 経由へ置換）。
- `CentralsFeature`: `CBPlaygroundLogging` 依存追加。`CBCentralScanInteractor` の `logLabel` / `log(_:)` を削除し、5 箇所のログを `@BLELog` 付きメソッドへ移行。`CBCentralManagerDelegate` 要件（戻り値を持てない）と `CBCentralManagerInteractorInput` 要件（Void）は薄い委譲メソッドにし、ログは結末文字列を返す private 本体メソッドへ寄せて 1 メソッド 1 ログを守る。
- `ios/project.yml`: `CBPlaygroundLogging` をローカルパッケージに追加。
- `Makefile`: `ios-build` から `-sdk iphonesimulator` を除去。`macro-test`（ホストで `swift test`）を追加し `ios-test` の依存に組み込む。
- `.github/workflows/ci.yml`: macro 展開テストを機械ゲート化する `macro-test` ジョブ（macos-15 + 最新安定 Xcode）を追加。

---

### D-016: 前提条件のあるメソッドは Void で受けない（throws / async で契約を型に出す）

**決定:** 前提条件のあるメソッドは Void で受けない。違反は throws で押し出し、待ちは async にする。`func foo() { guard cond else { return } ... }` の「Void + guard + silent return」は禁止する。`CBCentralManagerInteractorInput` の `startScan` / `stopScan` を `throws` 化し、違反は新設の `CBCentralManagerError`（`.notPoweredOn(CBManagerState)` / `.notScanning`）で表す。Presenter は do/catch で受け、View に `render(errorMessage:)` で伝える。

**理由:** 黙って no-op する API は、呼び出し側からは関数が走ったか走らなかったか区別できない。本リポジトリでは隠れた前提条件を `performStartScan() -> String` + `@discardableResult` というパターンで「結末を戻り値で語る」形に偽装してログ payload として消費していたが、`@discardableResult` が必要になる時点で「これは本物の戻り値ではない」というシグナル（戻り値は呼び出し側のためではなく、マクロの結末ログのためだけに存在していた）。throws で押し出せば、(a) 契約が型として明示され、(b) View がエラーを表示でき、(c) `@BLELog` の catch ブランチが `→ 失敗(<error>)` で自動的にエラーログまで取れる、と一石三鳥になる。`@discardableResult` の嘘の宣言も不要になる。

**影響範囲:**
- `CentralsFeature/Module/CBCentralManager/CBCentralManagerError.swift`: 新設。`.notPoweredOn(CBManagerState)` と `.notScanning`、`LocalizedError` 準拠。旧 `CBCentralScanInteractor.stateDescription(for:)` の状態文言は DRY のため Error 側へ移植し、Interactor からは削除する。
- `CBCentralManagerInteractorInput`: `startScan(filterNUS:allowDuplicates:) throws` / `stopScan() throws` に変更。`currentState()` / `discoveries()` は情報取得であり throws しない。
- `CBCentralScanInteractor`: `performStartScan` / `performStopScan` 委譲メソッドを撤去し、`startScan` / `stopScan` 自体に `@BLELog` を付ける。`@discardableResult` は本ファイル内の該当箇所から全廃。
- `CBCentralManagerPresenter`: `onStartTapped` / `onStopTapped` / `onViewDidDisappear` で `try` を do/catch で囲み、catch で `view?.render(errorMessage:)` を呼ぶ（`onViewDidDisappear` は元々スキャンしていない正常ケースでノイズになるので黙殺する）。
- `CBCentralManagerViewInput` / `CBCentralManagerViewController`: `func render(errorMessage: String)` を追加。実装は `UIAlertController` で最小通知する。
- delegate コールバック側 (`recordStateChange` / `record`) の helpers は今回触らない。これらは前提条件を隠していない（観察情報をログに載せるための別軸の議論）ため、本決定のスコープ外であり、別 PR で扱う。

---

### D-017: 動的 payload マクロ `@DynamicBLELog` を「切り札」として導入する

**決定:** 引数値ごとに本文を変えたい場面（例: `CBManagerState` の値ごとに「状態変化 unknown」「状態変化 poweredOn」のようにメッセージを分岐させたいケース）に限って使う「切り札」として、`@DynamicBLELog` body マクロを新設する。`@BLELog`（D-015）は `message: String` 固定文を前提とする「不自由なマクロ」であり、こうした分岐は表現できない。新マクロは `source:` クロージャで `DynamicBLELogPayload`（`level` / `message` / `label` を一括で持つ Sendable 値型）を返し、マクロ展開時にクロージャを関数本文末尾で呼んで結果を `BLELogRuntime.log(...)` に橋渡しする。展開は `@BLELog` と同じ「結果捕捉版」（入れ子関数 `__blelogBody` 退避＋ do/catch ラップ）に揃え、`async` / `throws` / 戻り値あり・なし・`Void` のすべてで一貫した展開とする。

**理由:** `CBCentralManagerDelegate.centralManagerDidUpdateState(_:)` のように戻り値を持てない Void 要件で、引数値（`CBManagerState`）の各 case ごとに観察文を変えたいケースが現れた。従来は `private func recordStateChange(_:) -> String` を `@discardableResult` で戻り値偽装して `@BLELog` の結末ログに横流ししていたが、これは戻り値の意味を歪める smell であり「1 メソッド = ログ 1 行」の規律と整合しない。回避策として「case ごとに `@BLELog` 付きの空ラッパメソッドを 8 個並べる」案も検討したが、空ラッパが量産されて可読性が落ちるため、`@BLELog` の不自由さを敢えて緩めた切り札マクロを 1 つだけ導入する方が綺麗に解決できると判断した。

**採用したクロージャ受け渡しの設計（B 案：仮引数経由）:** 当初は A 案（字義スコープ＝クロージャ本体を関数本文末尾へ inline 展開して関数引数や `self` をレキシカルに見せる）を試みたが、Swift は属性引数のクロージャを attribute スコープで型検査するため、関数引数（`central`）や `self` をクロージャ本体から直接参照することができない（コンパイル時 `cannot find 'central' in scope`／`'self' cannot be used on type` で弾かれる）。これは Swift の言語仕様によるものでマクロ実装側からは回避できない。そこで B 案を採用し、クロージャに関数引数を**仮引数として宣言**させ、マクロ展開時に関数引数をその仮引数へ渡して呼び出す形にした（`{ (central: CBCentralManager) in switch central.state { … } }(central)` の形）。マクロ宣言は `source: (repeat each Arg) -> DynamicBLELogPayload` の variadic generics で関数の引数数・型に汎用化する。

**失敗時の payload:** throws の catch 経路では `source:` クロージャを意味的に評価できない（成功時の値を組み立てるための関数）。そこで失敗時は別経路の静的指定とし、`failureMessage: String? = nil` と `failureLabel: String = "BLELog"` を属性引数で受ける。`failureMessage` 未指定なら `失敗(<error>)` のみ、指定があれば `<failureMessage> → 失敗(<error>)` を `.error` レベルで記録する。`failureLabel` の既定値 `"BLELog"` は、失敗時にどの label が一番目立つべきかが文脈依存であり、フォールバック値を一意に決められないため、診断容易性を優先して中立的なリテラルにした（本物の運用では呼び出し側が明示指定することを推奨）。

**戻り値ありメソッドへの適用:** 戻り値は payload クロージャからは見えない（クロージャは関数引数のみを仮引数として受ける）。これは将来要件としての保留事項であり、本マクロでは設計外。

**濫用への抑止:** 切り札は規律の例外であり、安易に使うと「1 メソッド = ログ 1 行」の不自由さが崩れる。マクロ自体は誤用を防げないため、抑止は doc・本意思決定ログ・PR レビューの 3 段で行う。原則は「まず `@BLELog` で表現できないか試す。表現できない（引数値で本文を変えたい・Void で結末を語りたい）場合のみ `@DynamicBLELog` を使う」とする。

**影響:**
- `CBPlaygroundLogging/Sources/CBPlaygroundLogging/DynamicBLELog.swift`: 新規。`@attached(body)` マクロ宣言（variadic generics で関数の引数列に汎用化）。
- `CBPlaygroundLogging/Sources/CBPlaygroundLogging/DynamicBLELogPayload.swift`: 新規。Sendable 値型。
- `CBPlaygroundLogging/Sources/CBPlaygroundLoggingMacros/DynamicBLELogMacro.swift`: 新規。BodyMacro 実装。`@BLELog` と同じ「結果捕捉版」展開を踏襲。
- `CBPlaygroundLogging/Sources/CBPlaygroundLoggingMacros/DynamicBLELogArguments.swift`: 新規。属性引数のパーサ（`failureMessage` / `failureLabel` / `source` クロージャ式の抽出）。
- `CBPlaygroundLogging/Sources/CBPlaygroundLoggingMacros/BLELogDiagnostic.swift`: `missingSource` 診断を追加。
- `CBPlaygroundLogging/Sources/CBPlaygroundLoggingMacros/Plugin.swift`: `DynamicBLELogMacro` を `providingMacros` に追加。
- `CBPlaygroundLogging/Tests/CBPlaygroundLoggingTests/DynamicBLELogMacroTests.swift`: 新規ユニットテスト（非 throws Void／throws Void（`failureMessage` あり・なし）／async Void／戻り値あり・非 throws の各パターン）。
- `CentralsFeature/Sources/CentralsFeature/Interactor/CBCentralScanInteractor.swift`: `private func recordStateChange(_:) -> String`（`@discardableResult` 付き）と `private func centralStateDescription(for:)` を撤去し、`centralManagerDidUpdateState(_:)` に `@DynamicBLELog` を直接付与。`@discardableResult` は本ファイルから全廃。

**D-015 との関係:** 本決定は D-015（`@BLELog` の規律）を否定するものではなく、補完するもの。`@BLELog` は引き続き既定であり、「不自由なマクロ」で 1 メソッド 1 ログを強制する。`@DynamicBLELog` はその不自由さで表現できない場面の切り札に限る。

---

### D-018: 共有 BLESession（async/await）導入・スキャン集約・CBPeripheral VIPER モジュール追加

**決定:** CoreBluetooth の async/await ラッパ `BLESession` を `CBPlaygroundCore` に導入し、`CBCentralManager` の所有を一本化する。`CBPeripheral` を 2 つ目の VIPER モジュールとして `CentralsFeature` に追加する。

**理由:**
- 複数モジュール（CBCentralManager, CBPeripheral, ...）がそれぞれ `CBCentralManager` を所有すると、Bluetooth ラジオが競合する（iOS は 1 アプリあたり CBCentralManager の同時使用に制限あり）。共有 `BLESession` に所有を集約し、上位層は BLESession を通じてのみ CBCentralManager を操作する。
- callback ベースの CoreBluetooth デリゲートを `CheckedContinuation` で async/await に橋渡しすることで、呼び出し側のコードが手続き的に読みやすくなる。
- 非要求イベント（切断通知、スキャン発見）は `AsyncStream` で渡す（後続の D-019 で Main Actor 同期コールバックへ上書き）。

**二重 resume 対策:**
- connect/discoverServices/discoverCharacteristics/discoverDescriptors の continuation は `[キー: continuation]` 辞書で保持する。
- resume 直後にキーを削除（`nil` 化）し、再入時は `alreadyInProgress` エラーを throw する（guard で早期リターン）。
- これにより「デリゲートが 2 回呼ばれる」「同一対象に 2 回 await する」の両方で二重 resume が起きない。

**影響:**
- `CBPlaygroundCore/Sources/CBPlaygroundCore/BLESession.swift`: 新規作成（BLESession + BLESessionError）。
- `CentralsFeature/Sources/CentralsFeature/Interactor/CBCentralScanInteractor.swift`: CBCentralManager 直所有・CBCentralManagerDelegate 実装を撤去し BLESession 利用へリファクタ。イニシャライザが `session: BLESession` を受け取る形に変更。
- `CentralsFeature/Sources/CentralsFeature/Module/CBCentralManager/CBCentralManagerRouter.swift`: `BLESession()` を生成して `CBCentralScanInteractor` に注入するよう変更。
- `CentralsFeature/Sources/CentralsFeature/Module/CBPeripheral/`: 新規 VIPER モジュール一式（CBPeripheralInteractorInput, CBPeripheralInteractor, CBPeripheralPresenter, CBPeripheralViewController, CBPeripheralRouter）。
- `CentralsFeature/Sources/CentralsFeature/Interactor/CBPeripheralInteractor.swift`: 新規具象 Interactor（BLESession 委譲）。
- `ios/CoreBluetoothPlayground/Screens/Topic.swift`: `case cbPeripheral` 追加。
- `ios/CoreBluetoothPlayground/Screens/TopicListViewController.swift`: `case .cbPeripheral: CBPeripheralRouter.assemble()` 追加。

---

### D-019: CoreBluetooth 型は Main Actor 完結で扱い `@unchecked Sendable` を全廃する

**決定:** `CBService` / `CBPeripheral` / `CBCharacteristic` / `CBDescriptor` が `Sendable` 非準拠なのは「CoreBluetooth は単一アクター（Main Actor）で扱う」という設計上の合図と解釈する。`BLESession` 配下では**非 Sendable な CB 値を隔離境界（`CheckedContinuation` / `AsyncStream`）を跨いで転送せず**、全処理を Main Actor 上で完結させる。具体的には:
- 探索系（`discoverServices` / `discoverCharacteristics` / `discoverDescriptors`）の continuation は `CheckedContinuation<Void, Error>` とし、制御フロー（成功＝`resume()`／失敗＝`resume(throwing:)`）のみを載せる。結果は `try await` 復帰後に Main Actor 上で `peripheral.services ?? []` 等を読み戻す。public シグネチャ（戻り値型 `[CBService]` 等）は不変。
- スキャン発見・切断イベントは `AsyncStream` ではなく **Main Actor 同期コールバック**で配る（`onDiscovery: ((Discovery) -> Void)?`）。同一アクター内の同期呼び出しは隔離境界を跨がないため、`Discovery` を `Sendable` にする必要がない。`Discovery` は素の `struct` に戻す（生の `CBPeripheral` と原文 `advertisementData` を保持する設計は維持）。

**根拠（実測）:** Swift 6.0・approachable concurrency（`defaultIsolation(MainActor)` / `NonisolatedNonsendingByDefault`）未有効では、Main Actor 隔離由来の値（`peripheral.services` 等）は disconnected region にならず `sending` を満たせない（診断: "main actor-isolated 'services' is passed as a 'sending' parameter"）。`AsyncStream` は Element に `Sendable` を要求する。よって境界を跨ぐ設計は `@unchecked Sendable`（および用途別キャリア `ServicesResult` / `CharacteristicsResult` / `DescriptorsResult` / `DisconnectionEvent`、旧 `SendableBox`）を不可避にしていた。境界を跨がない設計に変えることで、リポジトリ全体から `@unchecked Sendable` と `SendableBox` を全廃した（grep 0 件）。D-018 の「非要求イベントは `AsyncStream` で渡す」方針はこの D-019 で上書きする。

**D-016 との関係:** D-016（前提条件は throws で押し出す）は契約の見せ方（Void / silent return を避け、エラーで意図的に呼び出し側に届ける）に関する規約であり、本決定は Sendable / Actor 隔離（非 Sendable な CB 値を境界を跨がせない）という独立した別軸の議論である。両者は同じ `BLESession` / Interactor 周辺に作用するが互いに矛盾せず、本リポジトリでは併存する。

**トレードオフ:** イベント配送が `AsyncStream` から Main Actor クロージャになる（既存 Interactor の `onChange` と同流儀で、`scanTask` 購読が不要になり配線が単純化する）。`disconnectionEvents()` は消費側が無かったため関数ごと削除した。BLE delegate 処理は現状軽量なので Main Actor 同期で問題ないが、将来重い処理が出た場合のみ別途バックグラウンドへ逃がす。

**影響:**
- `CBPlaygroundCore/Sources/CBPlaygroundCore/BLESession.swift`: キャリア構造体・`DisconnectionEvent`・`disconnectionEvents()`・`scanContinuation` を撤去。`onDiscovery` プロパティと `isScanning` フラグを追加。`startScan` は戻り値なし、探索系は Void continuation + 読み戻しに変更。
- `CBPlaygroundCore/Sources/CBPlaygroundCore/Discovery.swift`: `@unchecked Sendable` を外し素の `struct` に戻す。
- `CentralsFeature/.../Interactor/CBCentralScanInteractor.swift` / `CBPeripheralInteractor.swift`: `AsyncStream` 購読（`scanTask`）を撤去し、`session.onDiscovery` を設定して `handleDiscovery(_:)` で同期蓄積する形に変更。`stopScan` で `onDiscovery = nil`。
