# BetterBudget 開發接手手冊

本手冊是工程、測試與 release 的共同操作基準。PR 改變架構、資料契約、工具或流程時，必須在同一個 PR 更新本文件。

## 產品領域與目前邊界

BetterBudget 是零基預算與共同帳本 Flutter App。核心流程是記錄收入／支出、把收入分配到預算類別、查看月統計，以及依平均、顯示收入比例、指定付款人或自訂金額分攤共同交易。Pro、付費主題與「同步到個人帳本」目前都是本機示範能力。

**已實作：** Flutter UI、Provider `BudgetController`、領域 service/model、`SharedPreferences` JSON 持久化、記憶體 repository 測試替身、月度預算與共同帳本計算、web build。

**尚未實作／計畫中：** production backend、帳號與驗證、多裝置離線同步、伺服器授權、真實 IAP／收據驗證、雲端 migration、監控與商店 release automation。目標設計見 [Production Backend Blueprint](PRODUCTION_BACKEND_BLUEPRINT.md)，不可把藍圖描述成現況。

## 架構

目前資料流：`Widget → BudgetController → BudgetService/SharedLedgerService → BudgetRepository → SharedPreferences`。Controller 同時承擔導覽相關狀態與 use-case 協調，repository 回傳同步 snapshot、寫入則為 async。

目標架構是 UI、application/use case、domain、data 四層，領域金額改為整數 minor units，local database 支援 transaction 與 migration，再透過 oplog 與 backend 同步。遷移必須漸進，既有 repository 契約有測試保護後才拆層。

## 目錄

- `lib/models/`：持久化模型與 JSON 映射。
- `lib/services/`：預算與共同帳本規則。
- `lib/data/`：repository 介面、本機與測試實作。
- `lib/screens/`、`lib/theme/`：Flutter UI、主題與格式化。
- `test/`：data、service、widget 與 tooling 回歸測試。
- `tool/`：可在本機及 CI 執行的 quality gates。
- `docs/`：產品、架構、audit、設計與上線規劃。

## 環境建置

使用 `pubspec.yaml` 宣告的 Dart SDK 與專案相容 Flutter stable。安裝 Flutter、確認 `flutter doctor`，接著：

```sh
flutter pub get
dart run tool/check_identifier_names.dart
flutter analyze
flutter test
flutter run -d chrome
```

若 `dart` 不在 PATH，使用同一 Flutter SDK 下的 `bin/dart`，不要混用另一版 SDK。任何 secrets 都必須由 CI secret store 或未納版控的環境設定注入。

### Android 正式簽署

Android `release` 不得使用 debug key。正式簽署可在未納版控的
`android/key.properties` 提供：

```properties
storeFile=/absolute/path/to/release-upload.jks
storePassword=replace-with-secret
keyAlias=release-upload
keyPassword=replace-with-secret
```

CI 可改用 `ANDROID_RELEASE_STORE_FILE`、`ANDROID_RELEASE_STORE_PASSWORD`、
`ANDROID_RELEASE_KEY_ALIAS`、`ANDROID_RELEASE_KEY_PASSWORD` 四個環境變數。兩種來源皆未
完整提供時，任何 Android release task 會以明確錯誤停止；debug Android 與 web 開發不會
要求 release credentials。`android/key.properties`、`*.jks` 與 `*.keystore` 已被忽略，
禁止將金鑰或密碼納入版控。正式建置前另確認 keystore 路徑存在，並由受控的 secret store
備份 upload key。

## 命名規範

所有自有檔案、class、Widget、function、變數、參數、callback／lambda 與 loop 參數都要以完整領域語意命名。禁止單字母、純數字與含糊縮寫。`_` discard、合法數學常數、外部 API 簽章，以及既有 JSON／持久化字串 key 是例外；例外不代表可把自有宣告命名為 `e` 或 `i`。

```dart
// 好
for (var categoryIndex = 0; categoryIndex < categories.length; categoryIndex++) {}
transactions.where((transaction) => transaction.isIncome);
final budgetController = context.watch<BudgetController>();
class _RecentTransactionRow extends StatelessWidget {}

// 壞
for (var i = 0; i < categories.length; i++) {}
transactions.where((t) => t.isIncome);
final c = context.watch<BudgetController>();
class _TxRow extends StatelessWidget {}
class _Item extends StatelessWidget {}
```

新名稱應描述角色而非型別：優先 `selectedCategory`、`memberIndex`，避免 `item`、`data`、`value`。檔名用完整 `snake_case.dart`。每次提交前執行命名檢查器；它掃描 `lib/`、`test/`，忽略字串、註解與 generated/build。

## Money 與資料完整性

目前 model 使用 `double`，所有入口必須拒絕非有限值、零／負分配與超額分配，顯示時才格式化；比較使用明確 tolerance。不得用格式化字串參與計算。共同分攤總和必須等於原交易金額，尾差由明確的最後成員吸收。

目標 backend 與新版 local schema 必須使用整數 minor units 加 ISO 4217 currency；禁止浮點跨 API。寫入交易與 allocation 要在同一 database transaction，ID 全域唯一，時間以 UTC 儲存、依使用者時區決定月份。任何 schema 變更都要保留舊資料、可重跑且有 rollback／restore 說明。

JSON field 與 `SharedPreferences` keys 是資料契約，不可因 Dart rename 更動。若必須改 key，新增版本化 migration：先讀舊版 fixture、轉換、驗證 count／sum／關聯，再寫新版與更新 schema version；測試 upgrade 與失敗恢復，禁止靜默丟棄資料。

## 開發流程與 TDD

1. 從 PRD、audit 與現有測試確認範圍，記錄「已實作／計畫中」。
2. 先寫失敗測試：service 規則用 unit test，repository 契約用 data test，互動回歸用 widget test。
3. 實作最小變更，保持 model/service/UI 邊界，不在 Widget 複製商業規則。
4. 執行 format、命名 gate、analyze、test、目標平台 build。
5. 自我 review 資料相容性、a11y、隱私與文件；PR 描述列出風險和驗證證據。

常用命令：

```sh
dart format lib test tool
dart run tool/check_identifier_names.dart
flutter analyze
flutter test
flutter test test/services/budget_service_test.dart
flutter build web
flutter pub outdated
```

測試不得依賴真實時鐘或網路；需要時間時注入 clock（目前待重構處要避免擴散 `DateTime.now()`）。修 bug 必須先建立能重現的 regression test。

## API、同步與 IAP 原則（計畫中）

目前沒有 production API 或 sync。未來 API 要版本化、驗證 schema、以 idempotency key 處理 mutation，授權必須在伺服器逐資源檢查。離線同步使用 operation log、tombstone、server cursor 與可觀測 conflict policy；金額與 allocation 需以 aggregate 保持原子性，不以 last-write-wins 拆散不變量。

目前 `upgradeToPro`／theme unlock 只寫本機狀態，不是購買證明。正式 IAP 必須由 App Store／Play 流程購買、server 驗證收據、保存 entitlement，支援 restore、退款與撤銷；UI 不得自行授權付費功能。

## UI、a11y、錯誤與狀態

沿用 `ThemeData` 與 design tokens，不在畫面散落品牌色。支援文字縮放、鍵盤、螢幕閱讀器語意、至少 48×48 logical pixel 觸控區、足夠對比；金額不可只靠顏色表意。新增流程要覆蓋 loading、empty、error、offline 與 retry，破壞性操作需清楚確認且可恢復。

領域 validation 回傳可理解的 typed failure（目前部分為 `ArgumentError`，屬待改善）；UI 對使用者顯示可行動訊息，不顯示 stack trace、token 或內部 ID。未預期錯誤保留 cause、release 與 correlation ID；production logging／Sentry 仍是計畫中。

## 資安與隱私

預算、收入、共同帳本與購買資料均視為敏感個資。只蒐集功能必要資料；log／analytics 禁止記錄金額、備註、成員姓名、auth token 或完整 payload。傳輸用 TLS，server 與備份加密，token 使用平台 secure storage，權限採 least privilege。新增第三方 SDK 前完成資料流、retention、刪除、consent 與供應商評估。提供帳號匯出／刪除是 backend 上線前門檻。

## Release 與故障排除

Release candidate 必須鎖定版本、產生 release notes、跑全部 quality gates、測試 migration／restore、檢查 privacy metadata 與商店 entitlement，並準備 staged rollout、監控與 rollback。backend 未完成前不得宣稱 cloud sync 或真實 Pro entitlement 已上線。

- `dart`／`flutter` 找不到：確認 PATH 指向同一 Flutter SDK。
- 套件解析異常：先 `flutter pub get`；必要時刪除可重建的 `.dart_tool` 後重試，不改 lockfile 逃避問題。
- SharedPreferences 測試互相污染：使用 `MemoryRepository` 或初始化 mock values。
- web build stale：確認 source gate 通過後再清理 `build/` 重建。
- 金額或月份錯誤：先檢查 currency unit、時區、month boundary 與 allocation 總和，不直接修 UI 顯示掩蓋資料錯誤。

## Definition of Done

- 驗收條件有測試，bug 有 regression test；TDD 證據可從 commit／PR 說明辨識。
- 自有 identifier 語意完整，命名 checker、format、analyze、全部 test 與受影響平台 build 通過。
- Money、分攤、月份與持久化不變量維持；schema/key 變更附 migration、fixture、restore/rollback。
- loading／empty／error／offline、a11y、privacy、security 與 telemetry 影響已 review。
- 清楚標示已實作與計畫中，不誇大 backend、sync 或 IAP 狀態。
- README、手冊、PRD、production plan 或 audit 在行為改變時同步更新。
- PR 有範圍、風險、截圖（UI 變更）及實際執行的驗證命令；無 secrets、generated build 或無關變更。
