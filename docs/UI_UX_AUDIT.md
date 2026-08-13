# BetterBudget（零基記帳）商業級 UI/UX 與無障礙審計報告

> 審計對象：/opt/data/workspace/budget-app（唯讀審計，未修改任何檔案）
> 基準：docs/UI_REDESIGN_PLAN.md v1.0 ＋ 最新偏好（首頁=Dashboard；快速記帳=FAB/側欄；待規劃角落入口；自由輸入金額、不加快捷金額）
> 工具驗證：`flutter analyze` → **No issues found**（3.0s）。以下問題均為分析器抓不到的 UI/UX/商業問題。

---

## 一、總評

**程式碼品質**：結構清楚、命名一致、分析器零警告，已具備不錯的「暖感極簡」視覺雛形（Hero 卡、待分配暖黃卡、類別橫滑卡均已實作）。
**上架差距**：距離「可真正商業上架」尚缺 **4 大支柱**——(1) 開機體驗（onboarding／預設類別／開機彈鍵盤 bug）、(2) 交易可逆性（無法編輯/刪除任何交易）、(3) 商店合規（無還原購買、無條款/隱私連結、示範模式字樣外露）、(4) 繁中本地化（無 flutter_localizations、App 名稱未中文化）。
**設計系統**：AppColors Token 已建立但被 `ColorScheme.fromSeed` 架空（半數死碼）；圖示三份重複 `_iconFor`；phosphor_flutter 相依零使用——與設計文件承諾的 Phosphor 不一致。

---

## 二、P0 問題（阻擋上架 / 明顯錯誤）

### P0-1 開機即彈鍵盤：autofocus 在 IndexedStack 隱藏頁中觸發
- 路徑：`lib/screens/root_screen.dart:188-195`（IndexedStack 同時建構 3 個 tab）＋ `lib/screens/add_transaction_screen.dart:165`（`autofocus: true`）
- 現象：App 啟動落在 Dashboard（index 0）時，「快速記帳」頁也被 build，其金額 TextField 取得焦點 → **首頁一開就跳出鍵盤**。
- 修法：移除 autofocus；改為 tab 切到 index 2 時再 `FocusNode.requestFocus()`（或用 lazy IndexedStack / 延遲建構）。

### P0-2 部分分配的收入被誤判為「已規劃完成」，待分配池看不到它
- 路徑：`lib/screens/allocation_screen.dart:41-45`（用 `isIncomeAllocated` 過濾）＋ `lib/services/budget_service.dart:131-132`
- 現象：`isIncomeAllocated` 只判斷「有沒有分配紀錄」，部分分配（如收入 40,000 只分了 12,000）也算「已分配」→ 待分配池列不出該筆；使用者從首頁暖黃卡點進去卻看到「本月收入都已規劃完成 🎉」，與 `unassigned > 0` 的卡片互相矛盾（`lib/screens/home_screen.dart:275-292` 同一套邏輯）。
- 修法：判斷改為「該筆收入分配總額 < 收入金額」；service 新增 `unassignedOfTransaction(txId)`，`isIncomeAllocated` 更名為 `hasAllocationRecord` 以正名。

### P0-3 未設上限的類別被誤判「超支」
- 路徑：`lib/screens/home_screen.dart:447`（`over = s.spent > s.category.monthlyLimit`）
- 現象：`monthlyLimit == 0`（未設上限）時，只要有任何支出就顯示紅字「超 X,XXX」＋ `warning_amber` 圖示＋紅進度條。未設上限＝不設限，不該有超支狀態。
- 修法：`over = s.category.monthlyLimit > 0 && s.spent > s.category.monthlyLimit`；進度條在無上限時顯示「已用 / 無上限」。

### P0-4 圓環圖中心「已用 X%」恆為 ~100%，誤導使用者
- 路徑：`lib/screens/home_screen.dart:347-349, 389`
- 現象：甜甜圈每片是「該類別佔總支出比例」——**結構上永遠加總 100%**；中心卻顯示 `expense / totalSpent × 100`，當所有支出都有分類時恆等於 100%。「已用 100%」同時搭配「總支出 NT$」標籤，邏輯自相矛盾。
- 修法：中心改顯示「總支出金額＋本月預算使用率（spent ÷ ΣmonthlyLimit）」；或把圓環改畫「各類別 spent/limit 目標環」。至少中心文字要與圖表同源。

### P0-5 缺少 flutter_localizations：系統 UI 全英文
- 路徑：`pubspec.yaml`（無 flutter_localizations）＋ `lib/main.dart:230-238`（MaterialApp 無 `localizationsDelegates`/`supportedLocales`）
- 現象：日期選擇器月份、文字選單（複製/貼上）、返回語意、輔助功能提示全部英文——繁中產品的致命傷。
- 修法：加 `flutter_localizations`，`supportedLocales: [Locale('zh','TW')]`，`locale` 預設 zh_TW。

### P0-6 平台顯示名稱未中文化
- 路徑：`android/app/src/main/AndroidManifest.xml`（`android:label="budget_app"`）、`ios/Runner/Info.plist`（`CFBundleDisplayName = "Budget App"`）
- 修法：改為「零基記帳」。

### P0-7 交易完全無法編輯／刪除（資料不可逆）
- 路徑：`lib/data/repository.dart:15,70,209` 有 `removeTransaction` 但 **全 app 無任何呼叫點**；`lib/screens/transactions_screen.dart` 列表無滑動刪除/長按編輯
- 現象：記錯一筆（金額/類別/日期）無法修正，只能眼睜睜看它算錯預算。記帳 App 的商業級基本要求。
- 修法：交易列表支援左滑刪除（Dismissible＋確認＋undo SnackBar）＋點擊進編輯；連動重算類別餘額與分配紀錄。

### P0-8 無 Onboarding、無預設類別種子
- 路徑：`lib/main.dart:236`（`home: RootScreen()` 直進）、`lib/data/repository.dart:272`（預設 planning=true，但類別為空）
- 現象：首次啟動就是空 Dashboard；「零基預算」概念沒有任何說明；新增支出時發現沒有類別要先去設定（`add_transaction_screen.dart:218-237` 才有補救）。YNAB 類產品的核心壁壘在於「教會使用者方法」，完全沒有引導等於自廢武功。
- 修法：3 頁 onboarding（理念→預設類別種子：伙食/交通/居住/娛樂＋建議上限→邀請設定第一筆收入）；首次啟動順序 Onboarding → Dashboard。

### P0-9 Paywall／主題商店不具上架資格
- 路徑：`lib/screens/paywall_screen.dart`（103 行「示範模式」字樣外露、無還原購買、無條款/隱私連結）、`lib/screens/theme_select_screen.dart:61`（同）
- 問題：①「示範模式：正式版將串接內購」直接顯示給使用者＝送審必退；②無 **Restore Purchases**（Apple Guideline 3.1.1 要求）；③無 Terms of Service／Privacy Policy 連結（2.3）；④比較表聲稱「免費版：有廣告」但 **App 內沒有任何廣告 SDK**——誤導聲明；⑤終身 NT$590 + 每主題 NT$90 的價格未經任何市場驗證、無本地化定價。
- 修法：接 RevenueCat / 原生 IAP；加「還原購買」；加條款/隱私頁；移除示範字樣；「廣告」列改成「無廣告（付費）／不影響記帳的有限廣告」或直接刪除該列。

### P0-10 類別／成員刪除無確認、無回復
- 路徑：`lib/screens/budget_settings_screen.dart:163-169`、`lib/screens/members_screen.dart:113-119`
- 現象：點垃圾桶立即永久刪除（類別連歷史交易、分配紀錄一併失聯，首頁 `_TxRow` 直接顯示 fallback「支出」）。
- 修法：AlertDialog 確認（類別需提示「歷史交易不會刪除但會變成未分類」）＋ SnackBar undo。

---

## 三、P1 問題（體驗明顯受損）

1. **月份切換無 UI**：`lib/screens/home_screen.dart:31` 標題「2026年8月 · 主頁」只是字串，controller 有 `prevMonth/nextMonth` 卻無入口（設計文件 C1 的 `< >` 未實作）。「· 主頁」後綴冗餘。
2. **類別順序與顏色跨畫面不一致**：`budget_service.dart:118-128` `categoryStats` 依「已分配金額」排序，但首頁橫滑卡用 stats 順序、預算設定用使用者拖拽順序、記帳頁用 repo 順序——**同一個類別在三處順序不同**；auto 色（`AppColors.categoryColorFor` 依 index）也隨之不同畫面不同色。使用者拖拽排序的努力在首頁失效。
3. **分配畫面未處理自動色**：`lib/screens/allocation_screen.dart:171-172` 直接 `Color(cat.colorValue)`，`colorValue == 0` 時 = 透明底黑字，與全 App 色彩系統脫節。應改用 `AppColors.categoryColorFor(cat, index)`。
4. **Hero 卡「本月可用餘額」語義錯誤**：`lib/screens/home_screen.dart:197-203` 顯示的是 `income − expense`（含未分配收入），在 ZBB 語境下「可用餘額」應是「已分配到類別但還沒花掉的錢」；進度條分母只用 ΣmonthlyLimit（`home_screen.dart:177-179`），未設上限則永遠 0%。數字與核心方法論不符，會動搖使用者信任。
5. **字型 runtime 下載**：`lib/theme/app_theme.dart:118-161` GoogleFonts 每次安裝後需連網下載 Noto Sans TC／Inter（未 bundle 進 assets）→ 冷啟動字型跳變、離線 fallback。修法：bundle 字型檔＋`GoogleFonts.config.allowRuntimeFetching = false`。
6. **文字縮放無 clamp**：固定高度容器（首頁類別卡 130、記帳頁類別網格 104、卡寬 130）在系統大字型（輔助使用）下溢出裁切。修法：`MediaQuery.withClampedTextScaling`（上限 1.3）或改彈性佈局；這是 WCAG 1.4.4 與商店無障礙稽核的常見扣分項。
7. **觸控目標過小**：色點 36px（`budget_settings_screen.dart:291`）、拖拽把手約 40px、多個 IconButton（刪除/編輯）無 tooltip——螢幕報讀只唸「按鈕」。iOS HIG／Android 建議 ≥44/48dp。
8. **無障礙語意缺失**：全 app 僅 9 處 tooltip；自訂互動元件（`_TypeCard`、類別網格、待分配卡）無 `Semantics(selected/button)`；圓環圖對 VoiceOver/TalkBack 完全不可讀（fl_chart 不提供語意）；裝飾性 icon 未 `ExcludeSemantics` 會產生噪音。金額只靠顏色區分收支的地方（`shared_ledger_screen.dart:234-237`）缺 +/- 符號。
9. **角落入口粗糙**：`lib/screens/home_screen.dart:34-39` 「規劃預算」icon 無文字標籤、無待分配金額 badge；fallback 進預算設定（`home_screen.dart:160-163`）與暖黃卡的 fallback 進分配池（`home_screen.dart:286-289`）行為不一致——同一件事兩個入口兩種結果。
10. **共同帳本交易不可刪除**：`removeSharedTransaction`（`lib/main.dart:214`）無任何 UI 呼叫點；誤記的共同支出永遠卡在帳本。
11. **深色模式切換藏在 Drawer 的 Dropdown**（`root_screen.dart:169-179`）：可發現性極差；應移入「外觀」設定頁（含主題商店）。
12. **圖示系統分裂**：`_iconFor` 在 3 個檔案重複定義（home/add_transaction/budget_settings）；`pubspec.yaml:42` 引入 phosphor_flutter 卻零使用，與設計文件 A5（全面 Phosphor）背道而馳。修法：抽單一 `AppIcons` registry。
13. **金額輸入允許多個小數點**：`add_transaction_screen.dart:168` 過濾只留 `[0-9.]`，「1.2.3」可輸入，存檔時才 tryParse 失敗提示。建議即時過濾第二個點＋小數位數限制。
14. **首頁與交易頁支出金額顏色不一致**：`home_screen.dart:547-553`（onSurface）vs `transactions_screen.dart:177-186`（error 紅）——同一筆支出兩種顏色語言。
15. **報表頁缺位**（PRD P1 範圍）：無圓餅/趨勢報表；Hero 卡點擊也無進入報表的提示。
16. **空狀態設計不達標**：首頁無交易僅一行灰字（`home_screen.dart:114-119`），與設計文件 B1-4 的完整空狀態（大 icon＋雙 CTA）不符；無 error state 設計（repo 異常無任何 UI）。
17. **SnackBar 一律底部**：與 FAB 重疊（`add_transaction_screen.dart:90-91`），設計文件建議置頂。

## 四、P2 問題（打磨項）

1. `formatMoney`（`lib/theme/app_theme.dart:232-241`）手寫千分位、負數靠巧合正確 → 統一改 `NumberFormat.decimalPattern`。
2. 版本號寫死（`root_screen.dart:183`）→ `package_info_plus`。
3. `firstOrNull` extension 在 6 個檔案重複定義（Dart 3 已內建）→ 全域刪除。
4. iOS 上日期選擇器用 Material 版（非 Cupertino）；建議依平台分流或至少啟用 localizations 後保持一致。
5. 分配畫面完成無任何成功動畫/觸覺回饋（設計文件 B3-5 的灑花/信封動效全未實作）；全 app 無 HapticFeedback。
6. `_openPlanning` 與暖黃卡的未分配查詢邏輯重複 → 抽成 service 方法。
7. App 圖示為 Flutter 預設、無品牌 splash screen。
8. 未尊重 `MediaQuery.disableAnimations`（減少動畫）。
9. 測試：僅 1 個 widget test（`test/widgets/transactions_screen_test.dart`），無 golden、無 a11y 測試。
10. Drawer header 為品牌標誌而非使用者（設計文件 B7 的會員感未做）；「管理/其他」分組文字用裸 `TextStyle(color: Colors.grey)` 未走 Token。

---

## 五、商業上架資訊架構（IA）提案

```
啟動（首次）→ Onboarding ×3 → Dashboard
啟動（回訪）→ Dashboard（記住上次月份）

■ 主畫面結構（RootScreen 改版）
├─ Dashboard（Tab 1，首屏）
│   ├─ AppBar：☰ ｜ 2026年8月 〈 〉 ｜ 🎯規劃預算(角落入口, 帶待分配 badge)
│   ├─ Hero 卡：本月可用餘額（= 已分配未花，語義修正）
│   ├─ 待分配暖黃卡（點→分配池，永遠顯示「剩多少未規劃」）
│   ├─ 預算圓環（中心=已用/預算 %，與圖表同源）
│   ├─ 類別卡橫滑（依使用者拖拽順序，非 allocated 排序）
│   └─ 最近交易（左滑刪除）
├─ 共同帳本（Tab 2）
└─ 快速記帳：FAB「＋ 記一筆」（全屏 route）＋ Drawer 入口（保留）

■ Drawer（側欄）
├─ 主頁 / 共同帳本 / 快速記帳
├─ 待分配池（NEW，帶金額 badge——補上「待規劃」的正式歸宿）
├─ 管理：預算設定、成員管理、全部交易
├─ 報表（NEW）
├─ 外觀：主題商店、深色模式（移到設定式頁面）
├─ 升級 Pro
└─ 設定：條款、隱私權、還原購買、版本
```

**要點**：Drawer 補「待分配池」正式入口（現況只有兩個隱性入口且行為不一致）；角落入口保留但加 badge＋語意標籤＋與分配池一致的 fallback。

## 六、設計系統提案（在現有程式基礎上補強）

1. **Token 單一來源**：現況 `AppColors` 定義了全套 token 但 `buildLightTheme` 用 `ColorScheme.fromSeed` 覆蓋，造成死碼＋主色漂移。改為 **AppColors → ColorScheme 直接映射**（或 fromSeed 後強制覆蓋 surface/primary 系列），讓設計文件 A2 的色票真正生效。
2. **Dimens 表**：設計文件 A4 的圓角/間距落成 `AppDimens`（radius: 6/10/16/20/24/999；space: 4/8/12/16/24/32），全 app 引用（現況大量 magic number：130、104、140…）。
3. **統一圖示 registry**：`AppIcons.byName(String)` 單一檔案，對照 Material→Phosphor（順勢完成設計文件 A5 的 Phosphor 化），刪除 3 份 `_iconFor`。
4. **共用元件庫**（現況每頁重造）：`MoneyText`（Inter tabular＋千分位＋收支色）、`AppProgressBar`（漸層/超支紅/脈衝）、`CategoryIcon`、`EmptyState`（icon+title+subtitle+CTA）、`SectionHeader`、`PrimaryCTA`。
5. **語意色規範**：收入=primary、支出=error，全 app 統一（修正 P1-14）；狀態色（剩餘/警示/超支）進 ColorScheme 擴充。
6. **無障礙基線**：全互動元件 ≥48dp 觸控、IconButton 一律 tooltip/semanticLabel、自訂元件補 Semantics、金額資訊永不只靠顏色、textScaler clamp 1.3、尊重 reduce motion。
7. **動效清單**：進場 fade/slide、數字 AnimatedCounter、FAB scale 0.95——依設計文件 B1-3 實作，但全部包在 `disableAnimations` 判斷內。

## 七、與 docs/UI_REDESIGN_PLAN.md 的差異（依最新偏好更新）

| 設計文件內容 | 最新偏好 | 動作 |
|---|---|---|
| B2-C 快速金額按鈕 [100][200][500]… | **不加** | 從計畫刪除該段落；保持自由輸入（現況已符合） |
| 記帳頁作為主 tab | 快速記帳＝FAB/側欄 | 維持現況（RootScreen index 2） |
| 無「待規劃角落入口」 | **要有** | 文件補 B1 AppBar 角落入口規格（icon＋badge＋fallback 規則） |
| B3 信封分配盤 +/- 步進按鈕 | 自由輸入優先 | 步進按鈕降為選配；保留「套用上月比例」智慧按鈕（低成本高價值） |
| B1 AppBar 月份 〈 〉 滑動切換 | 未提及 | 保留為 P1（現況完全缺入口，見 P1-1） |

## 八、建議修復順序（Roadmap）

1. **Week 1（可上架底線）**：P0-1 鍵盤 bug → P0-2/3/4 三個計算顯示 bug → P0-5 localizations → P0-6 命名 → P0-7 交易刪除/編輯 → P0-10 刪除確認。
2. **Week 2（留存）**：P0-8 Onboarding＋預設類別 → P1-1 月份切換 → P1-2 順序/顏色統一 → P1-4 Hero 語義 → P1-9/11 角落入口與 Drawer 重組（含待分配池）。
3. **Week 3（收入）**：P0-9 商店合規（IAP/還原購買/條款）→ 報表頁 → 主題商店接真 IAP。
4. **Week 4（品質）**：無障礙基線＋字型打包＋共用元件庫＋golden/a11y 測試。
