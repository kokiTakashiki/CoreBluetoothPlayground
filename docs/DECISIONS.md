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
