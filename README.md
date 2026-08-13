# BetterBudget

零基預算與共同帳本 Flutter App。目前資料保存在本機 `SharedPreferences`；production backend、跨裝置同步與真實 IAP 仍在規劃／開發階段。

## 新工程師 10 分鐘 Quick Start

前置：安裝與 `pubspec.yaml` 相容的 Flutter stable，並讓 `flutter`、同一 SDK 的 `dart` 位於 PATH。

```sh
git clone https://github.com/mightypresence/BetterBudget_App.git
cd BetterBudget_App
flutter doctor
flutter pub get
dart run tool/check_identifier_names.dart
flutter analyze
flutter test
flutter run -d chrome
```

前 10 分鐘應完成依賴安裝、三個 quality gates，並在 Chrome 看到首頁。若要驗證 release artifact，再執行 `flutter build web`。不要提交 `build/`、secrets 或本機設定。

開始修改前請依序閱讀：

- [開發接手手冊](docs/DEVELOPMENT_HANDBOOK.md)：架構、命名、Money、TDD、migration、release 與 DoD。
- [產品需求 PRD](PRD.md)：產品問題、使用者與功能範圍。
- [Production plan](docs/PRODUCTION_BACKEND_BLUEPRINT.md)：目標 backend／sync／IAP 與上線門檻，內容多數尚未實作。
- Audits：[核心資料](docs/CORE_DATA_AUDIT.md)、[UI/UX](docs/UI_UX_AUDIT.md)、[開發報告](docs/DEVELOPMENT_REPORT.md)。

提交 PR 前固定執行：

```sh
dart format lib test tool
dart run tool/check_identifier_names.dart
flutter analyze
flutter test
flutter build web
```

## Legacy 共同帳本 migration 限制

升級後第一次讀取舊版 `shared_transactions` 時，若交易沒有
`splitSnapshot`，App 會以升級當下仍存在的成員與其 `shownIncome`，套用該筆
交易原本的分攤模式計算一次並持久化。migration 不改變共同交易筆數或總金額，
且已有 snapshot 的交易不會再次計算；之後修改收入或移除成員也不會讓歷史分攤漂移。

舊格式沒有保存交易建立當時的完整成員／收入歷史，因此無法重建遺失的原始狀態；
migration 只能固化「升級當下」可取得的狀態。若當下沒有成員，snapshot 會固化為
空集合，不臆測歷史分攤。

同樣地，舊版個人鏡像支出沒有明確來源欄位，升級後不會用 ID prefix 猜測或回填關聯，
以免誤刪使用相似 ID 的個人交易。只有新版建立、帶有精確
`sourceSharedTransactionId` 關聯的個人鏡像，才會隨共同交易刪除。
