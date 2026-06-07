.DEFAULT_GOAL := help

# Variables
IOS_DIR := ios
SUBMODULE_DIR := firmware/nrf52840-ble-debug-bootstrap
BOARD ?= nrf52840dk_nrf52840
NCS_VERSION ?= v2.6.1
SAMPLE ?=
SERIAL_PORT ?=
CAPTURE_NAME ?=
VERBOSE ?=
SIM_NO_SIGN := CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=

.PHONY: help setup _bootstrap-ios _require-submodule upgrade \
        ios-project ios-build ios-format ios-format-check ios-test macro-test \
        flash-normal flash-anomaly capture-start capture-stop \
        verify run-sample collect list-samples clean clean-captures reset

## -----------------------------------------------------------------
## 公開ターゲット
## -----------------------------------------------------------------

help: ## 利用可能なターゲットを一覧表示する
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		grep -v '^_' | \
		awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: _bootstrap-ios ## iOS 用ツールを導入し、firmware 環境はサブモジュールへ委譲（初回のみ時間がかかる）
	@$(MAKE) _require-submodule && $(MAKE) -C $(SUBMODULE_DIR) setup NCS_VERSION=$(NCS_VERSION) BOARD=$(BOARD) || true

upgrade: ## 導入済みツールをアップグレードする
	@brew upgrade mint || true
	@echo "→ mint パッケージを更新するには: cd $(IOS_DIR) && mint bootstrap"

ios-project: ## project.yml から .xcodeproj を生成する（XcodeGen）
	cd $(IOS_DIR) && mint run yonaskolb/XcodeGen xcodegen generate

ios-build: ios-project ## シミュレータ向けにビルドする（署名なし）
	# -sdk iphonesimulator は付けない。これを付けると Swift Macro のコンパイラプラグイン
	# （CBPlaygroundLoggingMacros）までシミュレータ SDK でビルドされ、ホストで実行できず
	# 「produced malformed response」となる。-destination だけ指定し、プラグインはホスト
	# （macOS）向けに、アプリ本体はシミュレータ向けにビルドさせる。
	cd $(IOS_DIR) && xcodebuild \
		-project CoreBluetoothPlayground.xcodeproj \
		-scheme CoreBluetoothPlayground \
		-destination 'generic/platform=iOS Simulator' \
		build $(SIM_NO_SIGN)

ios-format: ## Swift ソースを整形する（SwiftFormat）
	cd $(IOS_DIR) && mint run nicklockwood/SwiftFormat swiftformat .

ios-format-check: ## 整形差分を検査する（書き込みなし、--lint モード）
	cd $(IOS_DIR) && mint run nicklockwood/SwiftFormat swiftformat --lint .

ios-test: ios-project macro-test ## シミュレータでテストを実行する（利用可能な最新 iPhone を自動選択）+ マクロ展開テスト
	@SIM=$$(xcrun simctl list devices available 2>/dev/null | grep -Eo 'iPhone [0-9]+' | sort -V | tail -1); \
	test -n "$$SIM" || { echo "→ 利用可能な iPhone シミュレータが見つかりません"; exit 1; }; \
	echo "→ テスト実行先: $$SIM"; \
	cd $(IOS_DIR) && xcodebuild \
		-project CoreBluetoothPlayground.xcodeproj \
		-scheme CoreBluetoothPlayground \
		-destination "platform=iOS Simulator,name=$$SIM" \
		test $(SIM_NO_SIGN)

macro-test: ## マクロ展開ユニットテストを実行する（ホスト macOS 上で swift test）
	# Swift Macro の展開はホスト（macOS）上でしか実行できないため、iOS シミュレータの
	# テストスキームには載せず、SwiftPM で直接 swift test する。
	cd $(IOS_DIR)/Package/CBPlaygroundLogging && swift test

flash-normal: _require-submodule ## 正常系 peripheral_uart を nRF52840 DK に書き込む
	$(MAKE) -C $(SUBMODULE_DIR) flash-dk BOARD=$(BOARD) SERIAL_PORT=$(SERIAL_PORT)

flash-anomaly: _require-submodule ## 異常注入ファームウェアを書き込む（SAMPLE=xxx を指定）
	@test -n "$(SAMPLE)" || { echo "→ SAMPLE が未指定です。例: make flash-anomaly SAMPLE=CBCharacteristic"; exit 1; }
	@echo "→ flash-anomaly は PR4 で実装予定です"
	@exit 1

capture-start: _require-submodule ## nRF Sniffer による BLE キャプチャを開始する
	@echo "→ capture-start は PR4 で実装予定です"
	@exit 1

capture-stop: ## キャプチャを停止して pcap を確定保存する（未起動でも正常終了）
	@echo "→ capture-stop は PR4 で実装予定です"

verify: _require-submodule ## DK 接続・Sniffer インタフェースの環境検証
	$(MAKE) -C $(SUBMODULE_DIR) verify

run-sample: ## 指定サンプルの検証準備を一括実行する（SAMPLE=xxx を指定）
	@test -n "$(SAMPLE)" || { echo "→ SAMPLE が未指定です。例: make run-sample SAMPLE=CBCentralManager"; exit 1; }
	@$(MAKE) _require-submodule

collect: ## Xcode ログと pcap を captures/ へタイムスタンプ付きで整理する
	@mkdir -p captures
	@TS=$$(date +%Y%m%d_%H%M%S); \
	if ls DerivedData/Logs/Test/*.xcresult 2>/dev/null | head -1 | grep -q .; then \
		cp -r $$(ls -t DerivedData/Logs/Test/*.xcresult 2>/dev/null | head -1) captures/xcode_$$TS.xcresult 2>/dev/null || true; \
	fi; \
	if ls captures/*.pcap 2>/dev/null | head -1 | grep -q .; then \
		echo "→ pcap ファイルはすでに captures/ にあります"; \
	fi
	@echo "→ collect 完了（DerivedData/Logs が空の場合は何もしない）"

list-samples: ## 実装済みサンプルを一覧表示する
	@echo "実装済みサンプル:"
	@find $(IOS_DIR)/Package -type d -path "*/Module/*" 2>/dev/null | \
		xargs -I{} basename {} | sort | \
		awk '{printf "  %s\n", $$0}' || echo "  (サンプルなし)"

clean: ## ビルド成果物を削除する（ソース・ツールには触れない）
	@rm -rf $(IOS_DIR)/.build $(IOS_DIR)/DerivedData || true
	@echo "→ clean 完了"

clean-captures: ## captures/ のキャプチャ成果物を削除する（.gitkeep は保持）
	@find captures -type f ! -name '.gitkeep' -delete 2>/dev/null || true
	@echo "→ clean-captures 完了"

reset: ## 生成物を削除して初期状態に戻す（再構築は make setup）
	@rm -rf \
		$(IOS_DIR)/CoreBluetoothPlayground.xcodeproj \
		$(IOS_DIR)/CoreBluetoothPlayground/Info.plist \
		$(IOS_DIR)/.build \
		$(IOS_DIR)/DerivedData \
		2>/dev/null || true
	@echo "→ reset 完了。再構築: make setup && make ios-build"

## -----------------------------------------------------------------
## 内部ターゲット（直接実行しない）
## -----------------------------------------------------------------

_bootstrap-ios: ## [内部] iOS ツール（mint 経由で SwiftFormat / XcodeGen）を導入する
	@command -v mint >/dev/null 2>&1 || brew install mint
	@cd $(IOS_DIR) && mint bootstrap

_require-submodule: ## [内部] サブモジュールが取得済みか確認する
	@test -f $(SUBMODULE_DIR)/Makefile || { \
		echo "→ サブモジュールが取得されていません。実行: git submodule update --init"; \
		exit 1; \
	}
