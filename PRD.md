# 記帳 App「零基預算分配」PRD（MVP）

> 日期：2026-08-07 ｜ 平台：Flutter（iOS / Android 跨平台） ｜ 狀態：MVP 開發中

## 1. 產品定位

以「**收入引導分配**」為核心特色的記帳 App（零基預算 / 信封預算概念）：

- 使用者記錄任何收入後，App 主動詢問是否要規劃這筆錢
- 開啟預算規劃後，引導使用者把收入分配到各筆預算類別
- 日常支出扣減對應類別的剩餘預算，即時顯示「還能花多少」

**核心差異化**：收入進來 → 主動引導分配（對話式流程），而不是被動記帳。

## 2. 使用者故事（核心流程）

> 小明今天收到 40,000 薪水，在 App 記錄這筆收入。
> 因為他開啟了預算規劃，App 問他「要怎麼規劃這 40,000？」
> 他把它分成：房租 12,000、伙食 8,000、娛樂 3,000、儲蓄 15,000、剩餘 2,000 留待分配。
> 之後每次支出（如買會員 500），從「娛樂」類別扣減，App 顯示娛樂剩 2,500。

## 3. MVP 功能範圍

| 功能 | 說明 | 優先級 |
|---|---|---|
| 記帳 | 收入/支出記錄：金額、類別、日期、備註 | P0 |
| 收入引導分配 | 收入輸入後詢問並引導分配到預算類別 | P0（核心） |
| 預算類別管理 | 新增/編輯類別、設定每月預算上限 | P0 |
| 餘額顯示 | 各類別：預算上限 + 分配收入 − 本月支出 = 剩餘可花 | P0 |
| 待分配池 | 未分配的收入進入「待分配」，可隨時補分配 | P0 |
| 本月總覽 | 本月收入/支出/結餘、類別圓餅圖 | P1 |
| 多帳戶 | 現金/銀行帳戶分開 | P2 |
| 銀行自動同步 | 開放銀行 API 串接 | P3（不做） |

## 4. 資料模型

```dart
enum TransactionType { income, expense }

class Transaction {
  String id;
  TransactionType type;
  double amount;          // 正數，以 type 區分方向
  String categoryId;      // 支出必填；收入可選
  DateTime date;
  String note;
}

class BudgetCategory {
  String id;
  String name;            // 如「伙食」
  double monthlyLimit;    // 每月預算上限（0 = 無限/未設定）
  String iconName;        // Material icon 名稱
  int colorValue;         // ARGB int
}

class Allocation {
  String categoryId;
  double amount;
}

class IncomeAllocation {
  String transactionId;   // 對應的收入交易
  List<Allocation> allocations;
  bool fullyAssigned;     // 是否已全部分配
}
```

## 5. 核心商業邏輯

### 5.1 記收入
1. 新增 `Transaction(type: income)`
2. 若使用者開啟預算規劃 → 進入引導分配流程
3. 收入金額加入「待分配池」（unassigned）

### 5.2 分配收入
1. 使用者對各類別輸入分配金額（可部分分配）
2. 規則：分配總和 ≤ 該筆收入金額
3. 分配後：類別本月「已分配」增加、待分配池減少
4. 已分配金額跨月結轉（類別餘額月結轉）

### 5.3 記支出
1. 新增 `Transaction(type: expense, categoryId)`
2. 該類別「本月支出」增加

### 5.4 類別餘額（核心公式）
```
本月餘額 = monthlyLimit + 本月分配收入 − 本月支出
（若無預算上限：本月餘額 = 本月分配收入 − 本月支出）
待分配池 = 本月所有收入 − 已分配金額
```

### 5.5 跨月行為（MVP）
- 每月 1 日：類別「已分配」重設為上個月結餘（未花完的分配滾入下月）
- MVP 簡化：僅統計當月，月結轉列為 P2

## 6. UI 畫面規劃

1. **首頁 Dashboard**：本月收入/支出/結餘卡片、待分配提示卡（點擊→分配）、類別餘額清單（進度條）
2. **記帳頁**：金額輸入、類型切換（收入/支出）、類別選擇、備註、日期
3. **分配引導頁**：顯示收入金額 → 類別清單輸入分配 → 剩餘未分配顯示 → 完成
4. **預算設定頁**：類別 CRUD、每月上限設定
5. **報表頁**（P1）：圓餅圖、趨勢

## 7. 技術架構

- Flutter 3.44.x（stable）/ Dart 3.12.x
- 狀態管理：Provider
- 本地儲存：`BudgetRepository` 抽象
  - App：SharedPreferences（JSON 序列化，MVP 夠用）
  - 測試：MemoryRepository
- 專案結構：
```
lib/
  main.dart
  models/          # 資料模型
  data/            # repository + 序列化
  services/        # BudgetService 核心邏輯
  screens/         # 頁面
  widgets/         # 共用元件
test/
  services/        # 核心邏輯單元測試
```

## 8. 驗收標準（MVP）

- [ ] 可記錄收入/支出，資料重啟後保留
- [ ] 收入輸入後出現「是否規劃」提示
- [ ] 分配流程可把收入分到多個類別
- [ ] 支出後類別餘額即時扣減
- [ ] 待分配池正確
- [ ] flutter analyze 無錯誤、核心邏輯單元測試全過
