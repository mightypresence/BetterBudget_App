# BetterBudget 商業上線完整系統計畫

> **For Hermes:** 使用外部 coding agent 分階段實作；每階段先測試、再實作、最後獨立驗收。  
> 日期：2026-08-12  
> 狀態：可執行藍圖；目前產品仍是本地 MVP，**尚不可販售上線**。

**Goal:** 將現有 Flutter「零基記帳」原型升級成可在台灣市場正式販售的 BetterBudget：商業級 UI、可靠帳務核心、雲端同步、共同帳本、正式 IAP、隱私合規、營運後台與可重複發布流程。

**Architecture:** Flutter 採 offline-first，裝置端用 SQLite 保存完整帳本；FastAPI 模組化單體提供身分、同步、共同帳本、entitlement 與營運 API；PostgreSQL 為雲端主資料庫、Redis 處理短期狀態與工作佇列。金額全面改用整數 minor units，所有同步資料有版本與冪等鍵；商店購買權限由後端驗證，不信任客戶端布林值。

**Tech Stack:** Flutter/Dart、Riverpod 或保留 Provider 並逐域拆 Controller、Drift/SQLite、FastAPI/Python、PostgreSQL、Redis、Alembic、OpenAPI、Docker、GitHub Actions、Sentry、OpenTelemetry、Apple StoreKit / Google Play Billing。

---

## 0. 已驗證現況

### 現有能力

- 個人收入／支出、收入分配、待分配池、類別預算。
- Dashboard、交易列表、預算管理。
- 共同帳本、成員、四種分攤模式、共同支出同步個人帳本。
- 亮／暗色與 7 款主題、Pro 與付費主題 UI。
- Repository abstraction、Provider controller、46 個既有測試。
- 2026-08-12 實測：`flutter analyze` 無 issue；46 tests pass，但原測試輸出含 Google Fonts binding 警告。
- Web release 可編譯並可載入；目前視覺仍是 MVP 級，且 Web metadata／品牌名稱未完成。

### 上線阻斷（P0）

1. **沒有真正 backend、帳號、雲端備份或跨裝置同步。**
2. **SharedPreferences JSON 不是生產帳務資料庫**：缺 schema migration、transaction、index、完整性約束、加密與大量資料效能。
3. **金額使用 `double`**：金融資料會出現浮點誤差；應改整數 minor units（台幣元）或 Decimal。
4. **Pro/主題購買是本地 demo boolean**，可任意解鎖，無收據驗證、恢復購買、退款與跨裝置 entitlement。
5. **共同帳本並非真正多人系統**：沒有邀請、成員帳號、角色權限、伺服器同步或衝突處理。
6. **資料刪除關聯不完整**：共同交易同步到個人帳本後，刪除共同交易不會回滾鏡像支出；刪除類別／成員也可能留下引用。
7. **金額與領域驗證不足**：0、NaN、Infinity、支出無類別、custom split 總額不等於交易金額等需由 service/domain 強制。
8. **品牌與 release 組態仍是模板**：`budget_app`、`A new Flutter project`、通用 icon、Android release 使用 debug signing。
9. **缺 privacy policy、terms、support、資料匯出、帳號刪除、Data Safety／App Privacy 答案。**
10. **缺 CI/CD、crash reporting、監控、備份恢復演練與 beta 發布流程。**

---

## 1. 產品定義

### 1.1 核心定位

**BetterBudget = 繁體中文、隱私優先、收入驅動的零基預算 App。**

核心承諾不是「記下花了什麼」，而是：

> 收入進來後，幫你把每一塊錢安排好；花費發生時，立刻知道每個目標還剩多少。

### 1.2 三條產品支柱

1. **個人零基預算**：收入分配、信封餘額、結轉、目標、週期性交易。
2. **共同生活財務**：情侶／家庭共同帳本、透明分攤、權限及個人隱私。
3. **溫暖而可信任的體驗**：繁中、台幣優先、無廣告、清楚數字、隱私預設。

### 1.3 V1 目標客群

- 台灣 22–40 歲上班族、自由工作者。
- 情侶／夫妻／同住者管理共同支出。
- 想做預算但覺得試算表或 YNAB 太複雜者。

### 1.4 V1 不做

- 銀行 Open API 自動同步。
- 投資組合、股票交易、貸款媒合。
- OCR 發票掃描與 AI 財務顧問。
- 多國稅務、企業會計。
- 廣告與出售財務資料。

這些會增加法遵、資安與產品複雜度，不能搶先於核心可靠性。

---

## 2. 完整資訊架構與 UI/UX

### 2.1 主導航

手機版採 4 個底部目的地，而非把核心功能全塞入 Drawer：

1. **首頁**：本月可用、待分配、類別預算、最近交易。
2. **預算**：全部信封、目標、結轉、分配入口。
3. **交易**：搜尋、篩選、編輯、刪除、週期交易。
4. **共同**：帳本切換、共同餘額、成員與分攤。

右上頭像／設定：帳號、主題、Pro、匯入匯出、隱私、安全、支援。快速記帳仍由首頁 FAB 與導覽入口開啟；**首頁永遠是 Dashboard，不是輸入表單**。

### 2.2 Onboarding

1. 品牌價值與隱私承諾。
2. 選擇幣別、月份起始日與財務目標。
3. 建立 3 個免費類別或套用範本。
4. 輸入第一筆收入。
5. 互動式分配收入。
6. 可跳過註冊先離線使用；啟用雲端備份／共同帳本才要求帳號。

### 2.3 Design system

- 8pt spacing grid；觸控區至少 44–48dp。
- 以語義 token 管理 `surface/primary/success/warning/danger`，禁止畫面內硬編色。
- 金額採 tabular figures；負值不只靠紅色，也要有負號、文字與 icon。
- 字體縮放 200% 仍可使用；所有 icon-only button 有 semantic label。
- Light/Dark/高對比；WCAG AA 對比作 release gate。
- Loading、empty、offline、syncing、error、retry、success state 都是正式元件。
- 破壞性操作提供明確確認與可撤銷窗口。

### 2.4 首頁重設

- Hero 顯示「本月可安心使用」及與上月比較，收入／支出為次級資訊。
- 待分配為明確行動卡；無未分配收入時顯示完成狀態，不留死入口。
- 類別只顯示前 4–5 筆，使用一致的進度、餘額與超支狀態。
- 空狀態直接引導「建立類別 → 記第一筆收入 → 開始分配」。
- 目前畫面大量空白、層級偏弱、收入與支出顯示 `+NT$ 0/-NT$ 0`、管理入口太像文字連結，都需重構。

### 2.5 關鍵流程驗收

- 新增交易 3 次點擊內可完成；連點提交不會重複。
- 可編輯／刪除交易，刪除會正確處理分配與同步鏡像。
- 所有表單有 inline validation、loading lock、錯誤復原。
- 所有頁面在 320px 寬、390×844、tablet、文字 200% 無 overflow。
- VoiceOver／TalkBack 能讀出金額、狀態與按鈕目的。

---

## 3. 正確帳務領域模型

### 3.1 金額

```text
Money {
  amount_minor: int64   // TWD = 元；JPY = 元；USD = cents
  currency: ISO-4217
}
```

- API JSON 以整數和 currency 傳輸，禁止 `double`。
- 分攤採 deterministic remainder：先算整數商，餘數按固定成員排序分配。
- 匯率不是 V1 核心；不同幣別不可直接相加。

### 3.2 核心實體

- User、Device、Session
- Workspace（個人／共同帳本）
- WorkspaceMember、Invitation、Role
- Account（現金、銀行、信用卡，可選 V1.1）
- Category、CategoryGroup
- BudgetPeriod、BudgetEnvelope、Allocation
- Transaction、TransactionSplit、TransferLink
- RecurringRule、Goal
- Entitlement、StoreTransaction
- SyncCursor、ChangeEvent、AuditEvent

### 3.3 必要約束

- amount_minor > 0；currency 合法。
- 支出一定有 category 或明確 `uncategorized` system category。
- Allocation 總和不可超過收入可分配額。
- custom split 總和必須等於交易金額。
- payer 必須是該 workspace 有效成員。
- 刪除使用 soft-delete tombstone，確保其他裝置能同步刪除。
- 所有 mutation 有 `idempotency_key`、`updated_at`、`version`。

### 3.4 月結與結轉

不以「每月一日 batch 重設」修改歷史數字。以不可變 period 計算：

```text
期末可用 = 期初結轉 + 本期分配 - 本期支出
下期期初 = 依類別 rollover policy 帶入期末可用
```

每個 period 保存快照與版本，重新計算可稽核。

---

## 4. Flutter 生產架構

```text
lib/
  app/                 routing, bootstrap, theme, localization
  core/                money, result, errors, network, database, sync
  features/
    auth/
    onboarding/
    dashboard/
    budget/
    transactions/
    shared_ledgers/
    billing/
    settings/
  design_system/       tokens, components, charts
  l10n/
```

### 4.1 本地資料

- Drift + SQLite，所有表有 migration。
- Secure Storage 只存 refresh token／裝置密鑰，不存整本帳務。
- Repository 本地優先；UI 先讀 DB stream，再由 sync engine 更新。
- 資料匯出：CSV + JSON backup；匯入先 dry-run 與錯誤報告。
- 敏感快照與 log 不含完整備註／金額，crash breadcrumbs 要 scrub。

### 4.2 狀態與導航

- 可保留 Provider，但將 241 行全域 `BudgetController` 拆成 feature controller；若換 Riverpod，必須逐域遷移，不能一次重寫。
- GoRouter 管理 deep link、邀請連結、paywall、登入回跳。
- Controller 不直接拼跨域 transaction；改由 use case/service 執行原子操作。

### 4.3 同步協定

1. 每個裝置生成 mutation UUID。
2. 本地 transaction 寫入 entity + outbox。
3. 背景 push 批次變更，server 以 idempotency key 去重。
4. server 回傳 global cursor；client pull cursor 後變更與 tombstones。
5. 一般文字欄位採 last-write-wins + version 檢測；財務核心若有衝突，保留兩版並要求使用者選擇，不能靜默覆蓋。
6. 網路恢復、app resume、手動刷新時同步；UI 顯示最後同步時間。

---

## 5. Backend 生產架構

### 5.1 形態

先做**模組化單體**，不做微服務：

```text
backend/
  app/
    auth/
    users/
    workspaces/
    budgets/
    transactions/
    sync/
    billing/
    notifications/
    admin/
  migrations/
  tests/
```

- FastAPI + SQLAlchemy 2 + Alembic + Pydantic。
- PostgreSQL；Redis 用於 rate limit、短期 token、job queue。
- Object storage 保存使用者匯出檔（短效 signed URL，自動過期）。
- 背景 worker 處理 email、push、商店通知、匯出、刪帳。

### 5.2 API 模組

- `/v1/auth/*`：Apple、Google、email magic link；refresh rotation、revoke。
- `/v1/me/*`：profile、devices、export、delete-account。
- `/v1/workspaces/*`：CRUD、邀請、接受、role、移除成員。
- `/v1/sync/push`、`/v1/sync/pull`：增量同步與 tombstones。
- `/v1/billing/*`：product catalog、verify purchase、restore、entitlements。
- `/v1/webhooks/apple`、`/v1/webhooks/google`：簽章驗證與去重。
- `/v1/admin/*`：只供後台，獨立 RBAC 與 audit log。

### 5.3 Auth 與權限

- Access token 短效；refresh token rotation + reuse detection。
- 每個 query 都有 workspace tenant scope，不能只靠前端傳 member id。
- Role：owner、admin、editor、viewer；敏感收入可設定 visibility。
- 邀請 token 單次、短效、可撤銷。
- 帳號 enumeration、暴力登入、webhook replay 都有限流與告警。

### 5.4 資安

- TLS、at-rest encryption、secret manager、環境分離。
- OWASP ASVS/MASVS checklist；dependency/SAST/secret scan。
- SQL tenant isolation 測試、IDOR 測試、rate-limit 測試。
- 備份每日、PITR；每季 restore drill。
- Audit log append-only，記錄 admin access、role、刪除、entitlement 變更。
- 生產資料不得直接複製到 staging。

---

## 6. 正式收費系統

### 6.1 建議商品

初版保持簡單：

- **Free**：完整基本記帳、3 個預算類別、本機使用。
- **BetterBudget Pro Lifetime**：一次買斷；無限類別、雲端備份、多裝置、進階報表、共同帳本。
- 付費主題可等 V1.1；首發避免過多 SKU 與審核複雜度。

NT$590 可作首輪測試價格，但正式價格需在 beta 訪談與競品查證後決定，不應視為既定事實。

### 6.2 Entitlement 流程

- Flutter 使用官方商店 IAP plugin／成熟抽象層。
- iOS StoreKit 與 Google Play Billing 啟動購買。
- receipt/purchase token 傳 backend 驗證。
- backend 將 store transaction 以唯一交易 ID 冪等入庫，計算 entitlement。
- App 只讀 server entitlement + 商店本地暫時狀態。
- 支援 restore、pending、cancel、refund、revoke、family/帳號轉移策略。
- Apple Server Notifications / Google RTDN 更新 entitlement。

Apple 官方說明 StoreKit 會處理付款並可由伺服器或 StoreKit 驗證交易；Google 官方建議將 Billing 與安全 backend 整合，以處理驗證與跨平台 entitlement。[3][6]

Google Play 上販售 app 功能與金融管理軟體等數位服務，原則上須使用 Play Billing（除政策允許的例外）。[4]

---

## 7. 隱私、法務與商店合規

- 公開 Privacy Policy、Terms、Support、資料刪除網頁。
- App 內：下載資料、登出所有裝置、刪除帳號、管理購買。
- Apple：若 App 支援建立帳號，必須可在 App 內發起刪除，不能只提供停用；刪除要說明訂閱處理。[1]
- Apple App Privacy 要申報 app 與第三方 SDK 收集的資料；財務資訊屬明列資料類型，公開 privacy policy URL 為必要欄位。[2]
- Google Play 所有已發布 app 都須完成 Data Safety，連「不收集資料」的 app 也要提交表單與 privacy policy；第三方 SDK 行為也在申報責任內。[5]
- 所有財務數據 analytics 採 opt-in 或只發送去識別事件；不傳金額、類別名稱、備註。
- 法務文件在正式販售前由台灣合格法律專業人士檢視；本計畫不是法律意見。

---

## 8. 觀測、營運與後台

### 8.1 產品事件（不含敏感內容）

- onboarding_started/completed
- first_income_created
- first_allocation_completed
- budget_category_created
- shared_workspace_created
- invite_accepted
- paywall_viewed/purchase_started/purchase_completed/restored
- sync_failed/recovered

### 8.2 KPI

- Activation：24 小時內完成「收入 + 分配 + 第一筆支出」。
- D1/D7/D30 retention。
- 每週完成分配使用者比例。
- 待分配清零率、超支後修正率。
- 邀請接受率、共同帳本雙人活躍率。
- Paywall → purchase conversion、退款率。
- Crash-free sessions、sync success、API p95。

目標值須由 TestFlight／Closed Testing 基線校準，不先虛構數字。

### 8.3 Admin

- 搜尋使用者只能看 metadata，預設不可看明文帳務。
- 手動 entitlement 需要理由、雙重確認及 audit。
- 查看 webhook、sync error、account deletion、export jobs。
- Feature flags、最低版本、maintenance banner。

---

## 9. 工程分期

### Phase 0 — Repository 與品質基線（1 週）

1. 把 `budget-app` 建成獨立 git repository 並設定 remote/branch protection。
2. 鎖定正式品牌、bundle IDs、app 名稱、icon、version 策略。
3. CI：format、analyze、test、web build、dependency/secret scan。
4. 修 P0 domain bug；把 46 tests 擴充到金額／刪除關聯／重複提交／split 約束。
5. 建立 golden screenshots 與 320/390/tablet accessibility tests。

**DoD:** 每個 PR 都有綠色 CI；無模板 metadata；release build 不用 debug key。

### Phase 1 — 帳務核心與本地正式版（2–3 週）

1. `double` → `Money(int64)` migration。
2. SharedPreferences → Drift/SQLite，有 migration、transaction、backup。
3. 編輯／刪除交易；關聯一致性與 undo。
4. 月結、結轉、週期交易、搜尋篩選。
5. 完整 onboarding、empty/error/offline UI。

**DoD:** 10k transactions 效能測試；migration 測試；crash 後資料不損壞；所有公式 property tests。

### Phase 2 — 全面 UI/UX 商業化（2–3 週，可與後端並行）

1. Design tokens、元件庫、四分頁導航。
2. 重做 Dashboard、預算、交易、分配、共同帳本、設定。
3. Responsive、dark/high contrast、動效、haptics。
4. VoiceOver/TalkBack、200% 字體、鍵盤與 reduced motion。
5. Store screenshots 所需完整 sample mode。

**DoD:** 核心流程 usability test；零 overflow；semantic audit 通過；golden baseline 核准。

### Phase 3 — Backend、Auth 與 Sync（3–5 週）

1. FastAPI skeleton、Postgres schema、Alembic、OpenAPI client generation。
2. Apple/Google/email auth、device/session management。
3. outbox + push/pull sync、tombstone、conflict UI。
4. 共同 workspace 邀請、RBAC、多人同步。
5. export、delete account、backup/PITR。

**DoD:** 兩裝置離線修改及復網 E2E；tenant isolation security tests；restore drill 成功。

### Phase 4 — Billing 與營運（2 週）

1. App Store Connect / Play Console 商品。
2. 真實 IAP、server verification、webhooks、restore/refund/revoke。
3. Paywall A/B 配置、analytics、Sentry、support/admin。
4. Privacy Policy、Terms、Data Safety、App Privacy。

**DoD:** Apple sandbox + Google license tester 全購買生命週期通過；客戶端改 boolean 無法解鎖。

### Phase 5 — Beta 與上架（2–3 週）

1. Internal QA → 20–50 人 closed beta → RC。
2. 真機矩陣、弱網、升級、刪帳、購買、恢復、同步測試。
3. App icon、screenshots、preview、描述、關鍵字、support URL。
4. TestFlight / Play closed track，修審核與 crash。
5. 逐步發布：5% → 25% → 100%，設定 rollback 與 kill switch。

**DoD:** 無開放 P0/P1；crash/sync/payment dashboard 可觀測；support runbook 完成。

---

## 10. 具體檔案演進

### 現有 Flutter

- 修改：`lib/main.dart`（拆 controller、routing/bootstrap）。
- 取代：`lib/data/repository.dart`（拆 interface、Drift local、remote sync）。
- 修改：`lib/services/budget_service.dart`（Money、驗證、period accounting）。
- 修改：`lib/services/shared_ledger_service.dart`（整數分攤、workspace 權限、鏡像關聯）。
- 重構：`lib/screens/*.dart` → `lib/features/*/presentation`。
- 保留並擴充：`lib/theme/app_theme.dart` → `lib/design_system/`。
- 新增：`lib/core/database/`、`lib/core/sync/`、`lib/features/auth/`、`billing/`、`settings/privacy/`。
- 新增：`integration_test/`、`test/golden/`、`test/accessibility/`。

### Backend

- 新增：`backend/pyproject.toml`、`backend/app/*`、`backend/migrations/*`、`backend/tests/*`。
- 新增：`infra/docker-compose.yml`、部署 manifests、監控告警。
- 新增：`.github/workflows/flutter-ci.yml`、`backend-ci.yml`、`release.yml`。

### 公開網站

- 新增：`site/privacy`、`site/terms`、`site/support`、`site/account-deletion`。

---

## 11. 測試矩陣

### Unit / property

- Money、rounding、allocation、rollover、split invariant。
- CRUD validation、permission、entitlement state machine。
- JSON/DB/API migration 與 backward compatibility。

### Widget / golden / accessibility

- 所有 empty/loading/error/offline/paid states。
- 320、390、tablet、light/dark、200% font。
- semantic labels、focus order、contrast。

### Integration / E2E

- onboarding → income → allocation → expense → dashboard。
- edit/delete/undo、月切換、export/import。
- 共同帳本邀請 → 兩裝置同步 → 分攤 → 移除成員。
- 離線新增 → conflict → reconnect。
- purchase → verify → restore → refund/revoke。
- account export → deletion → token revoke。

### 非功能

- 10k/100k transaction query benchmark。
- API load/p95、rate limiting。
- IDOR/tenant isolation、webhook replay、token theft。
- backup restore、migration rollback、store upgrade path。

---

## 12. 發布前不可妥協清單

- [ ] 正式 app 名稱、bundle IDs、icons、signing、privacy manifests。
- [ ] 不是 SharedPreferences 主儲存；所有 schema migration 有測試。
- [ ] 金額不使用 double。
- [ ] 帳號、sync、shared ledger 有完整授權與 tenant isolation。
- [ ] IAP 有 server verification、restore、refund/revoke。
- [ ] App 內資料匯出與刪帳；公開 privacy/terms/support URLs。
- [ ] App Privacy、Data Safety 與實際 SDK 行為一致。
- [ ] analyze/test/build、E2E、accessibility、security 全綠。
- [ ] 無 P0/P1 bug；所有錯誤有可觀測性與 runbook。
- [ ] 備份與還原實際演練成功。
- [ ] Closed beta 反饋處理完，才提交正式審核。

---

## 13. 決策建議

1. **先把產品定位與品牌定案，再全面重畫 UI**，否則會反覆返工。
2. **不要先做銀行串接**；先做到手動帳務可信、快速、可持續。
3. **共同帳本放在 Pro**，它也是後端與同步成本最高的功能。
4. **第一版只上一個 Pro SKU**，付費主題延後，降低付款與審核風險。
5. **本機模式必須可用**，但雲端備份／共同功能要求帳號；兼顧隱私與轉換。
6. **不把 Flutter Web 當首發主產品**；Web 先做展示、政策、帳號刪除與支援頁。主要商品為 iOS/Android。
7. **現有程式適合作為需求原型，不適合直接加 backend 後上架**；需要先完成 Money、SQLite、資料 migration 和 domain integrity。

## Sources

[1] https://developer.apple.com/support/offering-account-deletion-in-your-app — Apple: Offering account deletion in your app
[2] https://developer.apple.com/app-store/app-privacy-details — Apple: App privacy details
[3] https://developer.apple.com/documentation/storekit/in-app-purchase — Apple: In-App Purchase
[4] https://support.google.com/googleplay/android-developer/answer/10281818?hl=en-GB — Google Play payments policy
[5] https://support.google.com/googleplay/android-developer/answer/10787469?hl=en-GB — Google Play Data safety
[6] https://developer.android.com/google/play/billing — Google Play billing system
