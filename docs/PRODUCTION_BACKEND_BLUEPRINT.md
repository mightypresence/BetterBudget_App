# BetterBudget App 生產後端・商業化・資安・上架架構藍圖

> 版本：v1.0（藍圖，非實作紀錄）｜ 日期：2026-08-12 ｜ 適用專案：`/opt/data/workspace/budget-app`（「零基記帳」Flutter App）
> 標註說明：【現況】＝盤點專案程式碼/文件得到的既有事實；【查證】＝外部來源驗證事實（附 URL）；【估算】＝依公開費率計算（附公式）；【策略建議】＝本藍圖的設計決策，非事實、可被推翻。
> **重要聲明：本文件為架構藍圖，內容均為規劃。目前專案「沒有任何」後端、認證、IAP、推播、CI/CD 實作；文中所有「設計」「將」「應」皆為待建置項目，不可視為已實作。**

---

## 0. 執行摘要（TL;DR）

1. 現況為**純前端、全本地儲存**的 Flutter MVP（SharedPreferences + JSON），核心商業邏輯（零基預算分配、共同帳本分攤、私房錢）已有 44 個單元測試覆蓋，但**無後端、無帳號、無網路程式碼、無 IAP 金流（示範模式）、無 CI/CD、git 尚無任何 commit**。
2. 上線販售需要一次「從本地 App → 雲端服務」的轉型，建議採 **Postgres + Node.js/TypeScript API + 離線優先同步（oplog + LWW）** 架構，而非逐功能打補丁。
3. 商業化沿用既有定價（終身 NT$590 + 主題內購 NT$30–90）但**必須把權益驗證移到伺服器端**，否則可被繞過。
4. 最大風險是「終身買斷 + 免費雲端同步」的成本結構（一次性收入 vs 持續性伺服器成本），需以「免費版同步限額 / 雲端功能入 Pro」控制（見 §19）。
5. 建議六階段（M0–M5）約 19 週推進，先做**個人雲端同步**、再上 IAP 與上架、後做共同帳本雲端化。

---

## 1. 現況盤點與差距分析

### 1.1 現況（盤點事實）【現況】

| 面向 | 現況 |
|---|---|
| 平台/框架 | Flutter 3.44.x / Dart 3.12.x，Material 3，Provider 狀態管理 |
| 儲存 | 全部經 `BudgetRepository` 抽象 → `SharedPrefsRepository`（SharedPreferences + JSON 序列化）；測試用 `MemoryRepository`。**無任何本地 SQLite、無遠端資料庫** |
| 資料模型 | `Transaction`（double amount）、`BudgetCategory`（double monthlyLimit）、`IncomeAllocation/Allocation`（double）、`Member`（actualIncome/shownIncome，私房錢＝差額）、`SharedTransaction`（4 種分攤模式：equal/byIncomeRatio/byPayer/custom、`syncToPersonal`）、`ThemePreset`（premium 旗標） |
| 核心邏輯 | `BudgetService`（記帳＋收入引導分配＋待分配池＋類別餘額）、`SharedLedgerService`（分攤數學，含四捨五入吸收） |
| ID 生成 | `_newId()` = `prefix-微秒時間戳-隨機4碼`（非 UUID、非排序保證） |
| 付費 | `paywall_screen.dart` 為**示範模式**：`upgradeToPro()` 僅翻轉本地 bool（`setPro(true)`），主題解鎖僅寫入本地 `unlocked_themes`。無 StoreKit/Billing 程式碼 |
| 定價設計（文件） | 免費版（3 類別上限、2 主題、1 共同帳本）／Pro 終身 NT$590（早鳥 NT$390）／主題 NT$30–90（見 DEVELOPMENT_REPORT.md、競品研究文件） |
| 帳號/認證 | **無**。無登入、無多裝置概念 |
| 共同帳本 | 僅**單機**：成員與交易都存在本機 JSON，無邀請、無跨裝置、無跨使用者 |
| 網路 | **零**。pubspec 無 http/dio/firebase 等依賴 |
| 品質 | 44/44 單元測試、flutter analyze 零問題、Web 建置成功（開發報告自述） |
| 版本控制 | git repo 已 init 但 **0 commits**（master 無任何提交） |
| CI/CD、簽署、上架 | **無**（無 fastlane、無 CI 設定、無簽署憑證流程紀錄） |

### 1.2 差距清單（上線販售所需但現況缺項）

| # | 缺口 | 影響 | 藍圖對應章節 |
|---|---|---|---|
| G1 | 無帳號系統（認證/授權） | 無法跨裝置、無法共同帳本、無法管權益 | §5、§13 |
| G2 | 無伺服器端資料庫與 API | 資料僅存裝置，換機/刪 App＝資料滅失；無法備份 | §4、§5、§12 |
| G3 | 無同步與衝突處理 | 多裝置/多人編輯必然衝突，目前模型無法處理 | §6 |
| G4 | 共同帳本僅單機 | 「邀請成員」為假功能（只在本機新增名字） | §7 |
| G5 | IAP 為示範模式、權益存本地 | 可被繞過；無退款/還原/跨裝置處理 | §8 |
| G6 | 金額用 `double` 儲存 | 浮點誤差在財務 App 不可接受（分攤、四捨五入吸收邏輯目前靠測試兜底） | §4.1 |
| G7 | ID 非 UUIDv7/ULID | 離線生成 + 冪等同步需要排序、抗碰撞 ID | §6.3 |
| G8 | 無推播 | 無預算提醒、無共同帳本活動通知 | §9 |
| G9 | 無 analytics/crash | 上架後無法觀測品質與轉換漏斗 | §10 |
| G10 | 無 admin 管道 | 客訴/退款/封鎖/促銷碼無作業管道 | §11 |
| G11 | 無備份/還原 | 伺服器資料與用戶資料皆無災備 | §12 |
| G12 | 無 CI/CD、無簽署、無上架資產 | 無法穩定出包、無法送審 | §14、§15 |
| G13 | 無隱私合規文件 | 無隱私權政策、無 App Privacy/Data Safety 申報、無 DSA trader 聲明 | §13、§15 |
| G14 | git 零 commit | 無版本基線，無法回滾、無法審計 | §14（M0 第一件事） |

---

## 2. 目標架構總覽【策略建議】

```
┌────────────────────────── Flutter Client (iOS/Android) ──────────────────────────┐
│ UI (現有 screens) → BudgetController (Provider)                                   │
│ ── 新增層 ────────────────────────────────────────────────────────────────────   │
│ LocalStore: Drift(SQLite) ── 本地真源，離線可用                                    │
│ SyncEngine: outbox(冪等鍵) → push batch；cursor → pull changes；衝突偵測/回報      │
│ AuthClient: secure_storage 存取 token；自動 refresh                               │
│ IAPClient: RevenueCat SDK (purchases_flutter) + App Store Server API 驗證事件     │
│ Push: FCM/APNs token 註冊                                                          │
│ Obs: Sentry(crash/性能) + PostHog(事件漏斗，無 PII、無金額)                        │
└──────────────────────────────┬────────────────────────────────────────────────────┘
                               │ HTTPS/TLS 1.3（REST JSON /v1）
┌──────────────────────────────▼────────────────────────────────────────────────────┐
│ API Gateway (Cloud Run + Cloudflare, asia-east1)                                  │
│  Fastify/Node.js + TypeScript + zod 驗證 + 中介層(Auth/RBAC/限流/稽核)             │
│  Auth(OTP/Apple/Google) │ Personal CRUD │ Sync │ Ledgers/Invites │ Entitlements   │
│  Webhooks(RevenueCat/App Store V2/Play RTDN) │ Export │ Admin(獨立服務, SSO)      │
├───────────────────────────────────────────────────────────────────────────────────┤
│ Postgres 16（PITR）  │  Redis(限流/佇列)  │  佇列 pg-boss  │  物件儲存 R2/GCS(備份/匯出)│
│ FCM/APNs(推播)  │  Resend/SES(OTP 郵件)  │  RevenueCat  │  Sentry/PostHog           │
└───────────────────────────────────────────────────────────────────────────────────┘
```

原則：**Server 為權威（authoritative），Client 為離線快取**。金額不變式（分配總和 ≤ 收入、分攤總和 = 交易金額）一律在伺服器端以交易（transaction）方式強制；推導值（類別剩餘、月結轉）一律以 SQL 計算、不落儲存。

---

## 3. 建議技術選型

| 層 | 選擇（建議） | 備選 | 理由與注意事項 |
|---|---|---|---|
| 後端框架 | Node.js + TypeScript + **Fastify** + **Drizzle ORM** | NestJS（若團隊偏好 DI/模組化）；Dart **Serverpod**（單一語言） | Fastify 輕、型別友好；Drizzle 提供 compile-time 型別與遷移。Serverpod 優點是與 Flutter 同語言，但生態（收據驗證、管理工具、招募）較窄【策略建議】 |
| 資料庫 | **PostgreSQL 16**（託管：Neon 或 GCP Cloud SQL；若自管可用 Supabase 僅取其 Postgres） | SQLite + Turso（不建議，多人帳本需要伺服器端交易與權限） | 需要 RLS/交易/JSONB/PITR。GCP `asia-east1`（彰化）對台灣用戶延遲最低【策略建議】 |
| 快取/限流/佇列 | **Redis**（限流、短期快取）+ **pg-boss**（Postgres 佇列） | BullMQ（Redis 佇列） | pg-boss 免額外服務，早期夠用；量大再換 BullMQ【策略建議】 |
| 認證 | **自管 OAuth/OIDC**：Email OTP（magic link/code）+ Sign in with Apple + Google Sign-In；JWT access(15min) + refresh(30d, 輪換) | Clerk / Firebase Auth（加速） | 自管省月費、可控個資落地；不存密碼（純 OTP）＝免除密碼雜湊風險。Apple 審核要求：若提供第三方登入則需提供 Sign in with Apple（App Review 指引 3.1.1）【查證，見附錄】 |
| OTP 郵件 | Resend / AWS SES | SendGrid | 送達率與成本（每封 ≪ NT$1）【估算】 |
| 同步 | **自建 oplog + LWW + 伺服器權威合併**（本藍圖 §6） | PowerSync（Flutter 離線優先同步產品） | 財務不變式需要伺服器端裁決，自建可控；PowerSync 可省大量開發但合併語義受限、且多一層依賴【策略建議：Phase 1 自建，規模痛點出現再評估 PowerSync】 |
| 本地儲存（Client） | **Drift**（SQLite，取代 SharedPreferences JSON） | Hive/Isar（非 SQL，關係查詢弱） | 現有 `BudgetRepository` 抽象可直接替換實作，UI/Service 幾乎不動【策略建議】 |
| IAP/權益 | **RevenueCat**（purchases_flutter SDK + webhooks） | 自接 StoreKit 2 + Play Billing（省 1% 抽成但開發成本高） | 免費額度月追蹤營收 US$2,500 以下【查證，見附錄】；伺服器端仍須鏡像權益與驗證（見 §8） |
| 推播 | FCM + APNs（firebase-admin 統一閘道） | OneSignal | 自有資料、免額外 SDK 追蹤【策略建議】 |
| 觀測 | **Sentry**（crash/性能，Flutter SDK）＋**PostHog**（產品漏斗） | Firebase Analytics（iOS ATT 考量） | 兩者不預設使用 IDFA → 不需 ATT 彈窗（前提：不引入 AdSupport 框架）【策略建議】 |
| 基礎設施 | GCP **Cloud Run**（scale-to-zero）+ Cloud SQL/Neon + Cloudflare（CDN/WAF）+ R2（備份） | Fly.io + Neon（更簡單） | IaC 用 Terraform；`asia-east1` 對台延遲最低【策略建議】 |
| Admin | **Retool/Budibase** 連唯讀 Postgres 視圖 + 獨立 admin API（SSO+IP 白名單） | 自建 Next.js admin | 財務資料敏感：管理面僅限中繼資料，內容存取需 break-glass（§11） |
| CI/CD | **GitHub Actions** + **fastlane**（match 憑證、TestFlight/Play 上傳）+ Sentry CLI（source map） | Codemagic | iOS 建置需 macOS runner；Android 用 Play App Signing 讓 Google 代管簽章金鑰【策略建議】 |
| 金額表示 | **整數「分」（bigint cents）**，所有 API/SQL 皆以分為單位 | NUMERIC(19,4) | 現有 client `double` 需遷移；DB 層用 `bigint` + CHECK 約束，序列化 JSON 以「分」整數傳輸，避免浮點【策略建議＋G6 修正】 |
| ID | **UUIDv7**（client 端生成） | ULID | 時間排序 + 離線生成 + 抗碰撞，取代現有 `tx-微秒-隨機` 格式【策略建議＋G7 修正】 |

---

## 4. Postgres 資料表設計（核心 Schema，v1）

> 通用欄位：`id uuid`（主鍵）、`created_at/updated_at timestamptz`、`deleted_at timestamptz NULL`（軟刪除）、`client_updated_at timestamptz`（LWW 時鐘）、`server_seq bigint`（同步游標，見 §6）。金額一律 `bigint` 分。所有個人表帶 `user_id`；共同帳本表帶 `ledger_id`。以下為**建議 DDL 之示意**，非既有實作。

```sql
-- 帳號
CREATE TABLE users (
  id uuid PRIMARY KEY,                 -- 等同 auth 主體
  email text UNIQUE,                   -- OTP 登入者必有；Apple 隱私信箱模式可空
  email_verified_at timestamptz,
  display_name text, avatar_url text,
  locale text DEFAULT 'zh-TW', timezone text DEFAULT 'Asia/Taipei',
  status text DEFAULT 'active',        -- active|suspended|deleted
  marketing_opt_in bool DEFAULT false,
  analytics_opt_in bool DEFAULT true,  -- 預設允許非個資統計（隱私政策載明）
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 認證（不存密碼）
CREATE TABLE otp_codes (
  id uuid PRIMARY KEY, user_id uuid REFERENCES users(id),
  purpose text,                        -- login|email_verify|delete_confirm
  code_hash text NOT NULL,             -- 只存 SHA-256 雜湊
  expires_at timestamptz NOT NULL, attempts int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);
CREATE TABLE refresh_tokens (
  id uuid PRIMARY KEY, user_id uuid REFERENCES users(id),
  token_hash text UNIQUE NOT NULL,     -- SHA-256
  device_id uuid, app_version text, platform text,
  expires_at timestamptz NOT NULL, rotated_from uuid,
  revoked_at timestamptz
);
CREATE TABLE auth_providers (          -- Apple/Google 綁定
  user_id uuid REFERENCES users(id), provider text, subject text, -- provider+subject 唯一
  PRIMARY KEY (provider, subject)
);

-- 個人帳本
CREATE TABLE categories (
  id uuid PRIMARY KEY, user_id uuid REFERENCES users(id),
  name text NOT NULL, monthly_limit_cents bigint DEFAULT 0,  -- 0=未設上限
  icon_name text, color_value int, sort_order int, is_archived bool DEFAULT false,
  created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now(),
  deleted_at timestamptz, client_updated_at timestamptz, server_seq bigserial UNIQUE
);
CREATE TABLE transactions (
  id uuid PRIMARY KEY, user_id uuid REFERENCES users(id),
  type text NOT NULL CHECK (type IN ('income','expense')),
  amount_cents bigint NOT NULL CHECK (amount_cents > 0),
  category_id uuid REFERENCES categories(id),
  occurred_on date NOT NULL, note text DEFAULT '',
  source text DEFAULT 'app',           -- app|shared_sync|import
  shared_tx_id uuid,                   -- 來源共同帳本交易（稽核）
  deleted_at timestamptz, client_updated_at timestamptz, server_seq bigserial UNIQUE
);
CREATE TABLE income_allocations (
  transaction_id uuid PRIMARY KEY REFERENCES transactions(id) ON DELETE CASCADE,
  fully_assigned bool DEFAULT false,
  updated_at timestamptz DEFAULT now(), client_updated_at timestamptz
);
CREATE TABLE allocation_lines (
  allocation_tx_id uuid REFERENCES income_allocations(transaction_id) ON DELETE CASCADE,
  category_id uuid REFERENCES categories(id),
  amount_cents bigint NOT NULL CHECK (amount_cents > 0),
  PRIMARY KEY (allocation_tx_id, category_id)
);
-- 不變式（伺服器端強制）：SUM(allocation_lines.amount_cents) <= 對應 transactions.amount_cents（type=income）

-- 共同帳本
CREATE TABLE ledgers (
  id uuid PRIMARY KEY, name text NOT NULL, owner_user_id uuid REFERENCES users(id),
  type text DEFAULT 'shared', created_at timestamptz DEFAULT now(), deleted_at timestamptz
);
CREATE TABLE ledger_members (
  ledger_id uuid REFERENCES ledgers(id), user_id uuid REFERENCES users(id),
  role text NOT NULL DEFAULT 'editor' CHECK (role IN ('owner','editor','viewer')),
  status text DEFAULT 'active' CHECK (status IN ('invited','active','left','removed')),
  shown_income_cents bigint,           -- 共同帳本內可見收入（實際收入留在個人層，私房錢機制）
  joined_at timestamptz, PRIMARY KEY (ledger_id, user_id)
);
CREATE TABLE ledger_invitations (
  id uuid PRIMARY KEY, ledger_id uuid REFERENCES ledgers(id),
  inviter_user_id uuid, invitee_email text, invitee_user_id uuid,   -- 二選一
  role text DEFAULT 'editor', token_hash text UNIQUE,               -- 單次、7 天有效
  expires_at timestamptz, status text DEFAULT 'pending',            -- pending|accepted|revoked|expired
  created_at timestamptz DEFAULT now()
);
CREATE TABLE shared_transactions (
  id uuid PRIMARY KEY, ledger_id uuid REFERENCES ledgers(id),
  amount_cents bigint NOT NULL CHECK (amount_cents > 0), is_income bool DEFAULT false,
  category_name text DEFAULT '', occurred_on date NOT NULL, note text DEFAULT '',
  split_mode text CHECK (split_mode IN ('equal','byIncomeRatio','byPayer','custom')),
  created_by uuid, updated_by uuid,
  deleted_at timestamptz, client_updated_at timestamptz, server_seq bigserial UNIQUE
);
CREATE TABLE shared_tx_splits (
  shared_tx_id uuid REFERENCES shared_transactions(id) ON DELETE CASCADE,
  member_user_id uuid, amount_cents bigint, is_payer bool DEFAULT false,
  sync_to_personal bool DEFAULT true,
  PRIMARY KEY (shared_tx_id, member_user_id)
);
-- 不變式：SUM(amount_cents) = shared_transactions.amount_cents（byPayer 則僅一人）
CREATE TABLE personal_sync_links (     -- 稽核 shared→personal 同步
  shared_tx_id uuid, user_id uuid, personal_tx_id uuid,
  PRIMARY KEY (shared_tx_id, user_id)
);

-- 權益與 IAP
CREATE TABLE entitlements (
  user_id uuid REFERENCES users(id), entitlement_id text,           -- 'pro_lifetime' | 'theme:<id>'
  source text CHECK (source IN ('iap','promo','support_grant')),
  store text CHECK (store IN ('app_store','play_store','none')),
  product_id text, original_transaction_id text,
  purchased_at timestamptz, revoked_at timestamptz, raw_receipt jsonb,
  PRIMARY KEY (user_id, entitlement_id)
);
CREATE TABLE iap_events (              -- webhook 原始事件鏡像（重送/稽核）
  id bigserial PRIMARY KEY, user_id uuid, event_type text, store text,
  payload jsonb, received_at timestamptz DEFAULT now(), processed_at timestamptz
);

-- 同步與刪除墓碑
CREATE TABLE sync_cursors (
  user_id uuid, scope text,            -- 'personal' | 'ledger:<id>'
  last_server_seq bigint DEFAULT 0, updated_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, scope)
);
CREATE TABLE tombstones (
  entity_type text, entity_id uuid, scope text, deleted_at timestamptz, server_seq bigserial,
  PRIMARY KEY (entity_type, entity_id, scope)
);

-- 裝置與推播
CREATE TABLE devices (
  id uuid PRIMARY KEY, user_id uuid REFERENCES users(id), platform text,
  push_token text, app_version text, last_seen_at timestamptz DEFAULT now()
);
CREATE TABLE notification_prefs (
  user_id uuid PRIMARY KEY, budget_alert bool DEFAULT true, ledger_activity bool DEFAULT true,
  marketing bool DEFAULT false, quiet_start time, quiet_end time
);

-- 匯出（GDPR/備份）
CREATE TABLE user_data_exports (
  id uuid PRIMARY KEY, user_id uuid, format text,  -- json|csv
  status text DEFAULT 'pending', object_key text, expires_at timestamptz, created_at timestamptz DEFAULT now()
);

-- 管理
CREATE TABLE admin_users (id uuid PRIMARY KEY, email text UNIQUE, role text, created_at timestamptz);
CREATE TABLE audit_log (
  id bigserial PRIMARY KEY, actor_user_id uuid, actor_admin_id uuid, action text,
  entity_type text, entity_id uuid, before jsonb, after jsonb, ip inet, at timestamptz DEFAULT now()
);
CREATE TABLE feature_flags (name text PRIMARY KEY, enabled bool, rules jsonb);
CREATE TABLE promo_codes (code text PRIMARY KEY, entitlement_id text, max_redemptions int, used int DEFAULT 0, expires_at timestamptz);
```

設計重點：
- **租戶隔離**：個人資料以 `user_id` 分區；共同資料以 `ledger_id` 分區，存取一律經 API 層授權檢查（若用 Supabase 託管 Postgres 可疊加 RLS 作為第二道防線）。
- **推導值不落儲存**：類別「剩餘可花」、月結轉、成員結餘皆由 SQL 視圖/查詢即時計算（公式見 PRD §5.4），避免同步時推導值互相覆蓋。
- **`shared_tx_splits.sync_to_personal`**：對應現有模型，伺服器端在提交共同交易時產生**僅該成員可見**的個人交易（寫入 `transactions` + `personal_sync_links`），且 `actualIncome` 永不出個人層。

---

## 5. API 模組設計（REST，`/v1`，JSON）

所有寫入回傳資源現狀＋`server_seq`；所有列表用游標分頁（keyset）。錯誤格式統一 `{code, message, details}`。

| 模組 | 端點（示意） | 說明 |
|---|---|---|
| **Auth** | `POST /v1/auth/otp/request`、`POST /v1/auth/otp/verify`、`GET /v1/auth/oauth/apple`、`GET /v1/auth/oauth/google`、`POST /v1/auth/token/refresh`、`POST /v1/auth/logout`、`DELETE /v1/auth/devices/:id` | OTP 限流（每 email 5 次/15 分）、refresh 輪換＋重用偵測（重用＝撤銷家族）；Apple/Google 走 OIDC（nonce + code 交換） |
| **Me** | `GET/PATCH /v1/me`、`GET/PUT /v1/me/notification-prefs`、`POST /v1/me/delete`（兩階段確認） | 刪除帳號＝GDPR/個資法刪除權，連動 30 天軟刪＋可取消 |
| **個人帳本** | `GET/POST /v1/transactions`、`PATCH/DELETE /v1/transactions/:id`、`GET/POST /v1/categories`、`PATCH/DELETE /v1/categories/:id`、`PUT /v1/categories/order`、`GET/PUT /v1/allocations/:txId`、`GET /v1/stats/summary?month=`、`GET /v1/stats/by-category?month=` | 伺服器端驗證：金額為正整數分、類別歸屬、分配總和 ≤ 收入；統計端點回傳與 client 一致的計算（測試對拍） |
| **同步** | `GET /v1/sync/changes?scope=&cursor=&limit=`、`POST /v1/sync/push`（批次＋冪等鍵）、`GET /v1/sync/checkpoint`、`GET /v1/sync/conflicts` | 見 §6 |
| **共同帳本** | `POST /v1/ledgers`、`GET /v1/ledgers`、`PATCH /v1/ledgers/:id`、`DELETE /v1/ledgers/:id`（owner）、`GET/POST/DELETE /v1/ledgers/:id/members`、`PATCH /v1/ledgers/:id/members/:uid`（角色/離席）、`POST /v1/ledgers/:id/invitations`、`POST /v1/invitations/:token/accept`、`GET/POST /v1/ledgers/:id/shared-transactions`、`PATCH/DELETE /v1/ledgers/:id/shared-transactions/:id` | RBAC 中介層（owner/editor/viewer）；邀請 token 單次使用 |
| **權益/IAP** | `GET /v1/entitlements`、`POST /v1/entitlements/restore`、`POST /v1/entitlements/promo`（促銷碼）、Webhooks：`POST /webhooks/revenuecat`、`POST /webhooks/app-store`（App Store Server Notifications V2）、`POST /webhooks/play`（RTDN） | 見 §8 |
| **通知** | `POST /v1/devices`（註冊 push token）、`PUT /v1/me/notification-prefs` | token 去重/輪換；APNs/FCM 由伺服器佇列發送 |
| **匯出/備份** | `POST /v1/exports`、`GET /v1/exports/:id`（預簽 URL）、`POST /v1/imports` | GDPR 資料可攜＋自備備份；import 走 dry-run 驗證 |
| **Admin**（獨立服務/閘道） | `GET /v1/admin/users?q=`、`POST /v1/admin/users/:id/entitlements`、`DELETE /v1/admin/users/:id/entitlements/:eid`、`POST /v1/admin/promo-codes`、`PATCH /v1/admin/feature-flags/:name`、`GET /v1/admin/audit-log` | SSO＋IP 白名單；內容級資料需 break-glass 流程 |
| **Health** | `GET /livez`、`GET /readyz`、`GET /v1/version` | Cloud Run 探針＋client 強制升級檢查 |

---

## 6. 離線優先同步與衝突處理

### 6.1 模型：oplog + 伺服器權威 + LWW

- **本地為真源**：所有編輯先寫本地 Drift（即時 UI），再入 outbox 上傳；離線可無限使用。
- **伺服器為權威**：每筆接受的變更在 DB 交易內：驗證不變式 → 寫入 → 取 `server_seq`（全域遞增）→ 回傳。
- **拉取**：`GET /v1/sync/changes?cursor=<last_seq>` 依 `server_seq` keyset 分頁，含 tombstone（刪除的實體不消失，以墓碑傳播）。
- **時鐘**：`client_updated_at` 由裝置時鐘產生，但同步回應帶 `server_time`，client 持續計算偏差並校正；**排序只信 `server_seq`，不信裝置時鐘**。

### 6.2 衝突策略（分層）

| 情境 | 策略 |
|---|---|
| 同一欄位兩裝置都改 | **欄位級 LWW**（`client_updated_at` 較新者勝；同刻以 `user_id` 字典序決勝），loser 的值存進 `audit_log`/衝突回報 |
| 金額相關欄位（amount、split、allocation） | **實體級 LWW**：以「整筆交易」為原子單位取勝者（避免半新半舊破壞總和）；落敗方客戶端以「衝突快照」提示使用者，可一鍵復原【策略建議】 |
| 兩端同時「刪除同一筆」 | 墓碑冪等，無衝突 |
| 分配總和 > 收入（任一寫入） | 伺服器端 422 拒絕（永不入庫），client 本地保留並標記待修正 |
| 共同帳本同一交易兩人同時編輯 | 樂觀鎖：client 帶 `base_server_seq`（If-Match），不符回 409＋最新版，client 在本機 rebase 未上傳變更後重試；金額欄位若 rebase 後語義衝突 → 提示使用者裁決 |
| 類別被刪除但有交易引用 | 類別軟刪除（`deleted_at`），交易保留並顯示「已刪除類別」 |

### 6.3 冪等與 ID

- 所有 client 生成 ID 改用 **UUIDv7**（時間排序、離線可生成、抗碰撞）取代現有 `tx-微秒-隨機`【G7】。
- push 批次帶 `Idempotency-Key`；重複推送（網路重試）以主鍵唯一約束＋冪等鍵去重，回傳相同結果。
- 升級遷移：本地 JSON 資料首次登入時「一次性遷移」→ 上傳前以 UUIDv7 重寫 ID 並建立對照表，避免新舊 ID 混亂。

### 6.4 月結轉（rollover）的同步安全

- 月結轉、類別剩餘等**派生值全部伺服器端以 SQL 計算**（依 `occurred_on`），client 不儲存任何「已結轉」狀態；跨月結果在任何裝置、任何時區（以使用者 `timezone` 計算月份）一致。

---

## 7. 共同帳本：邀請、權限與隱私

### 7.1 邀請流程

1. 成員（owner/editor）輸入 email 或使用者 ID → `POST /ledgers/:id/invitations`。
2. 伺服器產生單次 token（opaque 隨機 256-bit，只存 SHA-256 雜湊，7 天有效），發送 deep link：`betterbudget://invite/<token>`（+ https 網頁落地頁）。
3. 受邀者開啟 App（無帳號則先走註冊/登入）→ `POST /invitations/:token/accept` → 原子寫入 `ledger_members(status: active)` 並將邀請標記 accepted；token 立即失效。
4. 邀請可撤銷（revoked）、可重發；邀請建立與接受皆寫 `audit_log`。限流：每帳本每日 20 封（防濫用）。

### 7.2 角色權限（伺服器端 RBAC 強制）

| 動作 | owner | editor | viewer |
|---|---|---|---|
| 查看帳本與統計 | ✓ | ✓ | ✓ |
| 新增/編輯/刪除共同交易 | ✓ | ✓ | ✗ |
| 邀請成員 | ✓ | ✓ | ✗ |
| 變更成員角色 | ✓ | ✗ | ✗ |
| 刪除帳本 / 轉移所有權 | ✓（轉移後方可離席） | ✗ | ✗ |
| 離席 | ✓（須先轉移） | ✓ | ✓ |

### 7.3 隱私範圍（對應現有「私房錢」模型）

- `Member.actualIncome`（真實收入）**永不上傳至共同帳本範圍**：共同層只存 `shown_income_cents`。私房錢（差額）為個人端計算。
- `sync_to_personal`：共同支出分攤寫入個人帳本時，產生**僅本人可見**的個人交易；其他成員不可見此衍生交易。
- 伺服器端測試必須驗證：非成員無法以任何 ID 組合讀取他人 `shown_income` 以外的資料（IDOR 防護，§13）。
- 離席時：若有未結算分攤，強制先「結算」（產生 settlement 交易或明確放棄），避免幽靈欠款。

---

## 8. IAP 權益（Entitlement）與金流

### 8.1 產品與權益對照

| 產品 | 類型 | 權益 ID | 價格（既定策略） |
|---|---|---|---|
| Pro 終身 | Non-consumable | `pro_lifetime` | NT$590（早鳥促銷碼 NT$390） |
| 主題包 ×4 | Non-consumable | `theme:<id>` | NT$30–90/款 |

免費版限制（3 類別、2 主題、1 共同帳本、同步限額）**伺服器端強制**——client 只做 UX 限制。

### 8.2 流程

1. client 用 RevenueCat SDK 發起購買 → StoreKit 2 / Play Billing 完成扣款。
2. RevenueCat webhook（驗證簽章）→ 伺服器寫入 `entitlements`＋`iap_events`。
3. **雙軌驗證**：另接收 App Store Server Notifications V2（`REFUND`/`REVOKE`）與 Play RTDN（`voidedpurchase`），Revocation 即時撤權（`revoked_at`）。
4. client 以 `GET /v1/entitlements` 取得權威權益快照；**Restore Purchases**（兩平台審核必備）＝觸發 RevenueCat restore → 伺服器重建權益。
5. 換裝置/刪 App：權益隨登入帳號恢復（綁 `user_id`，非裝置）。
6. 促銷碼：伺服器 `promo_codes` 表＋兌換端點（供早鳥行銷，不經商店）。

### 8.3 平台注意事項【查證，附錄】

- Apple 抽成：標準 30%；年營收 ≤ US$100 萬可申請 Small Business Program → 15%；訂閱次年 15%。Google Play：前 US$100 萬 15%，之後 30%；訂閱服務費 15%（2026 年美/英/EEA 有新版分費制度，以官方最新公告為準）。
- 非消耗型商品兩平台皆支援；iOS 非消耗型預設可 Family Sharing——**策略上建議關閉**（終身授權不應全家共享，除非產品有意）。
- 審核：需提供完整付費流程示範（sandbox 帳號＋測試收據）、隱私政策 URL、IAP 條款揭露。

---

## 9. 推播通知

- 技術：client 註冊 FCM/APNs token → `POST /v1/devices`；伺服器以 firebase-admin 統一發送（APNs 走 FCM 轉送）。
- 觸發（伺服器排程 pg-boss，全部依 `occurred_on` 與使用者時區計算）：
  - 類別「剩餘可花」低水位（如 <20%）
  - 每月 1 日月結轉摘要
  - 待分配池 > 0 提醒（核心特色，引導回分配流程）
  - 共同帳本活動：新交易、邀請被接受、分攤結算完成
  - 行銷（僅 `marketing=true` 且合規）
- 設計：payload 只放標題/提示文字，**不放金額明細**（鎖定畫面可見＝隱私洩漏）；安靜時段（`quiet_start/end`）不發；token 失效自動清理（FCM 回報 not-registered）。

---

## 10. Analytics 與 Crash

- **Sentry**：Flutter SDK；release 版號＋上傳 debug symbols/source maps（fastlane/Sentry CLI）；錯誤警報接 Slack/email；性能追蹤（記帳流程 P50）。
- **PostHog**：事件漏斗——onboarding → first_transaction → first_allocation → invite_sent → purchase_start → purchase_done；**事件只帶類別計數/桶化數值，不帶金額、不帶備註、不帶帳本成員姓名**。
- 隱私對齊：`analytics_opt_in` 可關；不整合 IDFA/AdSupport → 不觸發 ATT 流程（如未來加廣告 SDK 需重新評估）。
- 伺服器端：結構化 log（request_id、user_id、latency）＋ Cloud Logging；API 錯誤率/延遲告警。

---

## 11. Admin 後台

- 最小可用集（M3–M4 交付）：使用者查詢（id/email）、權益檢視與補發/撤銷、促銷碼管理、功能旗標、稽核日誌查詢、匯出請求處理、帳號停權/刪除。
- 安全：獨立 admin API 服務，SSO（Google OAuth 限定組織網域）＋MFA＋IP 白名單；**內容級資料（交易明細）預設不可讀**，需 break-glass 流程（寫入 audit_log、限時權限）。
- 資料介面：Retool 接唯讀資料庫視圖（隱藏金額明細欄位），寫入一律走 admin API。

---

## 12. 備份與還原

| 層 | 手段 | 目標 |
|---|---|---|
| 資料庫 | 託管 PITR（連續 WAL）+ 每日快照 | RPO ≤ 5 分鐘、保留 7–14 天 |
| 異地備份 | 每日 pg_dump（或 WAL 複本）→ Cloudflare R2/GCS，版本化＋object lock（防勒索） | 平台故障可重建 |
| 用戶自備 | 用戶可請求 JSON/CSV 匯出（GDPR 可攜）；提供 import 還原 | 用戶信任 |
| 演練 | 每季還原演練，runbook 紀錄 RTO 實測 | RTO ≤ 1 小時【目標值】 |

備份加密：靜態 AES-256（R2 預設）；匯出檔 24 小時過期、預簽 URL。

---

## 13. 資安與隱私：威脅模型與對策

### 13.1 STRIDE 威脅模型（重點條目）

| 威脅 | 情境 | 緩解 |
|---|---|---|
| Spoofing（偽冒） | 盜用他人 refresh token；偽造邀請 token | 短期 token＋輪換＋重用偵測；token 只存雜湊；邀請單次使用＋7 天 |
| Tampering（竄改） | 改寫 client 解鎖 Pro/主題（現況即可被改） | 權益伺服器端權威（§8）；API 回傳權益而非信本地 |
| Repudiation（否認） | 共同帳本成員刪帳不認帳 | audit_log 全寫入紀錄；共同交易保留創建者與時間 |
| Info Disclosure（洩漏） | IDOR 讀取他人交易/收入；鎖定畫面推播洩金額 | 每端點授權檢查＋自動化 IDOR 測試；推播不含金額；傳輸 TLS 1.3 |
| DoS（阻斷） | OTP 轟炸；邀請轟炸；API 灌流量 | 每 email/IP 限流；Cloudflare WAF；Cloud Run autoscale 上限＋預算告警 |
| Elevation（提權） | viewer 改角色、非成員讀帳本 | RBAC 中介層伺服器端強制；角色變更寫稽核 |

### 13.2 伺服器端清單

- OWASP ASVS 基準：zod 輸入驗證、參數化 SQL（Drizzle）、CORS 白名單、HSTS、安全標頭。
- 秘密管理：GCP Secret Manager；服務帳號最小權限；Terraform 管理（IaC）。
- 金鑰：JWT 簽署用 RS256（非對稱，可輪換）；OTP 6 碼 + 5 次嘗試上限 + 5 分鐘有效。
- 依賴掃描（`npm audit`、Dependabot）、容器掃描（Artifact Analysis）；每版安全回歸測試（IDOR 矩陣、不變式模糊測試）。

### 13.3 客戶端清單

- token 存 `flutter_secure_storage`（iOS Keychain / Android Keystore）；無密碼儲存（純 OTP）。
- R8/ProGuard 縮減＋混淆；Dart `--obfuscate`；不在 client 內嵌任何 secret。
- 選配：root/jailbreak 偵測提示（財務 App 建議）、憑證固定（後期視威脅評估）。

### 13.4 合規

- **台灣個資法**：隱私權政策（資料項目、用途、保存期間、權利行使管道）、刪除權/可攜權 API（§5 Me/Exports）、行銷需同意。
- **App Store Privacy（App Privacy 標籤）＋ Google Play Data Safety form**：申報蒐集項目（email、交易資料；不蒐集精確位置/聯絡人）。
- **EU DSA trader 聲明**：App Store Connect 與 Play Console 均需申報 trader 身分與聯絡資訊（即便只上架台灣也需完成宣告，Apple 官方載明）【查證，附錄】。
- 兒童資料：不面向兒童，App 內容分級 4+／Everyone，政策載明 13+。
- 事件應變：資安事件聯絡管道＋72 小時通報程序（GDPR 適用範圍）寫入 runbook。

---

## 14. CI/CD 管線（GitHub Actions）

```
PR → [flutter analyze + flutter test] [backend: lint + typecheck + unit test]
   → merge main → 建置矩陣：
     Android: gradle assembleRelease (aab) → fastlane beta → Play internal
     iOS:     macOS runner → fastlane match → build → TestFlight
     Backend: docker build → Artifact Registry → dbmate/prisma migrate deploy → Cloud Run deploy（金絲雀 10%）
   附：Sentry source map 上傳、版本 tag（semantic-release）
```

- 簽署：Android 用 **Play App Signing**（Google 代管上架金鑰，本地只持 upload key，存 GitHub Secrets）；iOS 用 App Store Connect API key＋match（cert/profile 加密入 repo）。
- 環境：`dev`（本地 docker-compose）→ `staging`（Cloud Run 獨立專案，接測試商店沙盒）→ `prod`。
- 遷移策略：僅向前遷移＋expand-contract（先加欄、再切讀、再刪舊欄）；每次 deploy 前自動備份快照。
- 品質門檻（pipeline 內）：單元測試 100% 通過、`flutter analyze` 零問題、API 契約測試（OpenAPI 生成 client）、整合測試於 staging。

---

## 15. App Store / Google Play 上架清單

**共同前置**
- [ ] 開發者帳號：Apple Developer Program（US$99/年）、Google Play Console（US$25 一次性）【查證，官方價格，見附錄】
- [ ] 隱私權政策與服務條款網址（審核必備）
- [ ] DSA trader 聲明（兩平台）
- [ ] 資料安全申報：App Privacy（Apple）＋ Data Safety（Play）
- [ ] 商品建立：Pro 終身（NT$590 各商店對應價位層）＋4 主題；促銷碼設定
- [ ] 測試帳號（sandbox）與審核備註（如何走完付費流程）

**App Store**
- [ ] Bundle ID、App 圖示、6.7"/5.5" 截圖、預覽影片（選）
- [ ] Export Compliance（HTTPS 加密 → 通常豁免）
- [ ] TestFlight 內部測試 → 外部測試 → 提交審核
- [ ] IAP 條款揭露於商品頁；Restore Purchases 按鈕（審核檢查點）
- [ ] 若日後加第三方登入以外的第三方 SDK，需檢視 4.2/5.1 資料條款

**Google Play**
- [ ] 新 App target API 36（Android 16，2026 新提交要求）【查證，附錄】
- [ ] 內容分級問卷、目標受眾（13+）
- [ ] 封閉測試（新個人帳號通常須 ≥12 位測試者連續 14 天方可申請正式版；以 Play Console 現行政策為準）
- [ ] Play App Signing 啟用、上傳 aab、staged rollout（10%→50%→100%）
- [ ] 資料安全表單與 developer 身分驗證（組織帳號需 D-U-N-S）

**台灣稅務（開放問題）**：Apple/Google 付款視為 B2B 跨境勞務，統一發票與營業稅處理建議由會計師確認（本藍圖不給稅務結論）【策略建議：上架前諮詢會計師】。

---

## 16. 成本模型（月營運，估算）【估算】

| 項目 | 選型 | 月成本（低流量<1 萬 MAU） |
|---|---|---|
| 運算 | Cloud Run（scale-to-zero，低流量近乎零） | ~US$0–10 |
| 資料庫 | Neon Free / Cloud SQL 最小規格 | US$0–40 |
| 物件儲存＋CDN | R2/Cloudflare Free | ~US$0–5 |
| OTP 郵件 | Resend（每封 ~US$0.001 級）| <US$5 |
| IAP | RevenueCat Free（MTR ≤ US$2,500） | US$0 |
| 觀測 | Sentry Free、PostHog Free | US$0 |
| 簽署/上架 | Apple US$99/年（≈US$8.3/月）、Play US$25 一次性 | ≈US$8 |
| **合計** | | **約 US$15–70/月（≈NT$500–2,300）** |

營收估算（每筆 Pro NT$590、15% 平台費 → 淨 ≈ NT$501；主題 NT$30–90 同率）——**成本結構警示**：終身買斷無續約收入，但雲端成本持續；若免費版開放全量雲端同步，成本隨使用者線性成長（見 §19-R1）。【估算，費用皆以 2026-08-12 公開價目為準、隨時浮動】

---

## 17. 階段里程碑（M0–M5，約 19 週）

| 階段 | 週數 | 範圍 | 出口條件（節選） |
|---|---|---|---|
| **M0 基線與工程衛生** | 0–2 | git 首次 commit＋.gitignore 完備；GitHub repo＋PR 流程；CI 骨架（analyze/test）；套件名/品牌定名；金額 `double`→int 分 的模型遷移計畫 | CI 綠燈；main 有保護規則；所有現有 44 測試通過 |
| **M1 個人雲端同步** | 3–6 | 後端骨架（Fastify＋Drizzle＋Postgres＋Redis）；OTP＋Apple/Google 登入；個人 CRUD API；Drift 本地庫＋oplog 同步引擎；tombstone；PITR 備份；staging 環境 | 雙裝置離線→上線同步正確；斷網重試冪等；備份還原演練通過 |
| **M2 IAP＋首版上架** | 7–10 | RevenueCat 串接；伺服器權益＋退款撤權 webhook；真付費牆與 Restore；促銷碼；上架資產（圖示/截圖/隱私政策）；TestFlight＋Play 封閉測試 | 沙盒購買→權益生效→退款→撤權全鏈路測試通過；兩平台審核通過（正式/測試軌） |
| **M3 共同帳本雲端** | 11–14 | ledgers/members/invitations/RBAC；共同交易同步＋分攤伺服器驗證；sync_to_personal；帳本活動推播 v1；最小 admin（權益補發） | 邀請→接受→共同記帳→分攤→個人帳本落帳全流程多裝置驗證；非成員存取測試全被拒 |
| **M4 營運化** | 15–18 | Sentry/PostHog 全埋點；預算低水位與待分配推播；用戶匯出/import；admin 完整（促銷碼/功能旗標/稽核）；安全檢視＋滲透測試（輕量）；SLO 儀表板 | 漏斗事件可視；p95 API 延遲 <300ms；安全測試修正完畢 |
| **M5 成長** | 19+ | 多帳戶、週期性交易、CSV、發票載具（台灣差異化）；銀行同步 P3；AI 建議 | 依數據決策，非本藍圖硬性範圍 |

---

## 18. Definition of Done（DoD）

**每個功能/任務**：
- [ ] 對應單元/整合測試通過；新 API 有契約測試（OpenAPI）
- [ ] 金額不變式由伺服器端強制（非僅 client）
- [ ] RBAC/IDOR 測試矩陣通過；審計事件寫入
- [ ] 遷移腳本可正向執行且可回滾計畫已備
- [ ] Sentry release＋版本號標註；文件（runbook/API doc）更新

**每個里程碑**：上表「出口條件」全數達成＋資安清單（§13.2）無高風險未決項＋備份還原演練紀錄。

**正式上線（Production Launch）門檻**：

- [ ] CI 執行 `dart run tool/check_identifier_names.dart`，拒絕單字母、純數字與含糊自有 identifier；`dart format`、`flutter analyze`、`flutter test`、目標平台 build 全數通過
- [ ] 每項功能的 Definition of Done 包含同步維護 `docs/DEVELOPMENT_HANDBOOK.md`、README、PRD／production plan／audit（依影響範圍），並明確區分已實作與計畫中
- [ ] 兩平台審核通過；權益金流全鏈路（購買/還原/退款/撤權）在沙盒與少量真實用戶驗證
- [ ] 隱私政策/Data Safety/DSA trader 申報完成；刪除帳號與匯出功能可用
- [ ] PITR＋異地備份＋還原演練紀錄；事件應變 runbook＋聯絡人
- [ ] 監控告警（API 錯誤率、p95、登入異常、費用預算）上線；on-call 名單
- [ ] staged rollout 有回滾劇本（版本回退＋DB 向前相容）
- [ ] 免費版伺服器端限制（3 類別等）上線前壓測驗證不可繞過

---

## 19. 風險與開放問題

| # | 風險/問題 | 建議 |
|---|---|---|
| R1 | **終身買斷＋免費雲端同步＝成本無上限** | 免費版同步限額（如 1 裝置、N 筆/月）或雲端同步為 Pro 權益；主題內購做為持續營收。需產品決策【策略建議】 |
| R2 | 現有 `double` 金額遷移會動到全部模型與既有測試 | M0 內以「整數分」重寫模型＋測試對拍（期望值不變），一次性完成，勿延後 |
| R3 | 共同帳本「私房錢」定位：實際收入若上傳個人層仍屬敏感資料 | 依 §7.3 分層：實際收入僅存個人範圍；欄位級加密列為選配評估 |
| R4 | RevenueCat 免費額度超出（MTR>US$2.5k） | 屆時費率 1%（MTR 超出部分）；或評估自建收據驗證。屬成長煩惱，不阻擋起步 |
| R5 | 平台政策變動（Google 2026 分費改制、target API 逐年調升） | 上架前再次核對官方政策頁（附錄）；年度檢視 |
| R6 | 台灣稅務/發票（跨境勞務、營業稅） | 上架前諮詢會計師；本藍圖不給結論 |
| R7 | 單人/小團隊維運負擔 | 全託管服務優先（Cloud Run/Neon/RevenueCat/PostHog），自管範圍壓到最小 |
| R8 | 共同帳本語義未定：分攤後個人帳本「預算類別」如何映射（現況 syncToPersonal 直接扣個人預算） | M3 前產品決策：預設映射類別規則（如全部入「家庭支出」類別） |

---

## 20. 附錄：可驗證 URL 清單

> 價格/政策類資料以 2026-08-12 抓取之公開來源為準，上架與採購前請以官方現行頁面重新確認。

**商店抽成與費用**
- Apple Small Business Program（15%）：https://developer.apple.com/app-store/small-business-program/
- Apple 官方新聞稿（15% 計畫原始公告）：https://www.apple.com/newsroom/2020/11/apple-announces-app-store-small-business-program/
- Google Play 2026 新分費公告：https://android-developers.googleblog.com/2026/03/a-new-era-for-choice-and-openness.html
- RevenueCat「15% 商店費用指南（2026）」：https://www.revenuecat.com/blog/engineering/small-business-program

**IAP / 平台政策**
- RevenueCat 定價（Free ≤ US$2,500 MTR）：https://www.revenuecat.com/pricing
- Google Play target API 要求（2026：新 App 須 API 36）：https://developer.android.com/google/play/requirements/target-sdk
- Apple DSA trader 要求官方說明：https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/

**專案內來源（本地）**
- `/opt/data/workspace/budget-app/PRD.md`（產品需求、核心公式）
- `/opt/data/workspace/budget-app/docs/DEVELOPMENT_REPORT.md`（開發報告、定價策略）
- `/opt/data/workspace/budget-app/docs/UI_REDESIGN_PLAN.md`（UI 規劃）
- `/opt/data/競品研究_記帳App功能與收費分析.md`（競品定價表：YNAB US$109/年、Money Lover 終身 ~NT$600、麻布 NT$690→1,499、記帳城市 NT$2,290/年）

---

*（文件結束）本藍圖為規劃文件；任何「已實作」陳述僅限 §1.1【現況】表。*
