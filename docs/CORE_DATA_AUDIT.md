# BetterBudget 程式與資料完整性審計

> 日期：2026-08-12  
> 基線：審計時 `flutter analyze` 無問題、46 tests 通過；第一批修復後為 52 tests。  
> 範圍：`lib/`、`test/`、SharedPreferences persistence、個人與共同帳本。

## P0

### 1. 跨月收入進入分配頁可能 StateError

- `lib/screens/allocation_screen.dart` 以 `BudgetController.transactions` 查收入；該集合只包含 controller 當月。
- 新增交易可以選其他月份，新增後立即開分配頁，查不到便崩潰。
- 修復：指定交易應從完整 repository 安全查找，或先切 controller 月份；找不到時顯示可恢復錯誤。

## P1

### 2. 部分／空分配會鎖死收入

- `isIncomeAllocated` 只看是否存在 allocation record。
- 部分分配甚至空清單一旦保存，會被誤認為完成；待分配池仍有錢但沒有入口。
- 修復：以 `income amount - total allocated` 判定完成，允許重新進入修改；禁止空分配。

### 3. monthlyLimit=0 誤報超支

- 0 的領域語義是無上限，但首頁及新增支出警告把任何支出判為超支。
- 修復：只有 `monthlyLimit > 0 && spent > monthlyLimit` 才超支。

### 4. 刪除類別留下 dangling references

- 歷史交易與 allocation 仍引用已刪類別，會造成待分配及統計對不上。
- 正式策略：有引用時禁止硬刪；提供停用／歸檔，或引導重新分類並把 allocation 退回待分配。

### 5. 歷史共同分攤會漂移

- 分攤每次依現在的 members 與 shownIncome 重算。
- 新增、刪除成員或修改收入會改寫過去各月結果；個人同步鏡像仍保留舊值。
- 正式策略：SharedTransaction 建立時保存 immutable split snapshot；成員採 deactivate，不硬刪歷史身份；收入比例以期間快照計算。

### 6. 交易無正式編輯／刪除流程

- Repository 有 remove 方法，但交易 UI 無完整入口。
- 共同交易刪除也沒有補償同步至個人帳本的鏡像支出。
- 正式策略：使用 `sourceSharedTransactionId` 關聯，原子建立／編輯／刪除鏡像。

### 7. SharedPreferences 無法承擔正式帳務資料

- 無 DB transaction、migration、index、備份、匯出及錯誤復原。
- 正式策略：Drift/SQLite + schema migration + JSON/CSV export + 雲端同步。

## P2

1. 金額是 double，需改 int64 minor units。
2. 多處 read-modify-write 非原子，表單沒有一致的 saving guard，連點可能重複或覆蓋。
3. JSON 解析無 schema version、migration 與損毀復原。
4. 共同帳本同步自動建立類別，可繞過免費類別上限。
5. Donut 百分比分子分母相同，幾乎恆為 100%。
6. categoryStats 按 allocation 重排，覆蓋使用者自訂順序。
7. 月份切換方法存在但沒有 UI 入口。
8. 金額輸入允許多個小數點，僅由 parse 失敗處理。
9. allocation controller 生命週期與 build 中建立 controller 需整理。
10. 主題數量文案與實際商品數量不一致。

## 第一批已修復

- 拒絕 0／NaN／Infinity 金額。
- 支出無有效類別時拒絕寫入。
- 不完整 category reorder 不再遺失未列項目。
- 刪除收入交易同步刪除 allocation。
- Google Fonts 測試 binding 警告已消除。
- SharedPrefsRepository 開始有回歸測試。

## 後續驗收

- 所有領域不變式必須在 service/domain 層強制，而不只在 UI。
- 所有刪除必須有關聯策略與測試。
- 共同分攤總和永遠等於交易金額。
- Allocation 總和不超過收入，剩餘金額永遠可重新進入分配。
- 離線／重開／升版／損毀資料都不能靜默丟帳。
