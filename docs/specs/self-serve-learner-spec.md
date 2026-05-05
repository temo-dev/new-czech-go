# Self-Serve Learner Spec

**Slice:** V17 — Self-Serve Learner Auth + Profile + Streak + Pro Paywall
**Status:** Draft (chưa implement)
**Owner:** TBD
**Last updated:** 2026-05-05

Liên quan:
- Idea: `docs/ideas/self-serve-learner.md` (sẽ tạo)
- Plan: `docs/plans/self-serve-learner-plan.md` (sẽ tạo)
- Design: `docs/designs/self-serve-learner.html` (sẽ tạo)

---

## 1. Mục tiêu

Cho phép học viên Việt **tự đăng ký, đăng nhập, xác minh email, theo dõi streak, và mở khóa Pro qua Apple IAP** — không cần admin can thiệp.

Trước slice này: chỉ tồn tại 2 dev token hardcode trong `MemoryStore.usersByToken`; không có bảng `users`, không có signup, không có lifecycle thật. Slice này thay thế hoàn toàn fixture-based identity bằng database-backed lifecycle.

### Why now

- LLM/Polly/ElevenLabs cost thực tế đã hiện hữu ở V14 (interview) và V15 (image gen). Cần paywall để bù chi phí.
- App đã đủ tính năng (V1–V16) cho real launch — gating chỉ còn auth.
- App Store reviewer yêu cầu user account flow + privacy controls khi submit production.

### Out of scope (V17)

- OAuth (Google/Apple Sign In) — defer V18
- Web learner UI — Flutter iOS only
- Stripe / Android billing — chưa có Android build
- Class/cohort, teacher role — không trong product scope
- Learner-to-learner social, leaderboard — defer
- Forgotten email recovery — chỉ recover password, không recover email account

---

## 2. Quyết định đã chốt

| # | Quyết định | Lý do |
|---|---|---|
| 1 | Email + password (bcrypt cost 12) | Quen thuộc, reuse pattern admin auth, không SMS cost |
| 2 | Email verify **grace mode**: 3 attempts trước khi ép verify | Giảm friction signup, vẫn chống spam (Variation V2 inversion) |
| 3 | Streak tính theo timezone `Asia/Ho_Chi_Minh` server-side | Không tin client clock; UTC dễ lệch ngày với học viên Việt |
| 4 | Pro = Apple IAP only V17 | Flutter iOS only; Stripe defer khi có web/Android |
| 5 | Free tier: 7 attempts/ngày + 1 interview/tuần | Đủ tự ôn cơ bản; cap LLM cost |
| 6 | Pro: unlimited + 1 streak grace pass/tuần + mock test full | Streak grace = retention hook |
| 7 | Email infra: AWS SES (region `eu-central-1`, cùng S3) | Stack đã dùng AWS; không thêm vendor mới |
| 8 | PII lưu: email, name, avatar URL, push_token, onboarding goal/level | Tối thiểu cần cho personalize + reminder |
| 9 | Migration: prod scrub sạch trước launch; dev tokens chỉ seed khi `ENV != production` | An toàn data — không carry over fixture |
| 10 | Spec lưu tại `docs/specs/self-serve-learner-spec.md` | Theo convention `docs/specs/<topic>.md` |

---

## 3. Domain model

### 3.1 Bảng mới — `users`

```sql
CREATE TABLE users (
    id                  TEXT PRIMARY KEY,                -- nanoid 21 ký tự
    email               TEXT NOT NULL,
    email_normalized    TEXT NOT NULL,                   -- LOWER(TRIM(email)) cho lookup
    email_verified_at   TIMESTAMPTZ,                     -- NULL = chưa verify
    password_hash       TEXT NOT NULL,                   -- bcrypt $2a$12$...
    display_name        TEXT NOT NULL DEFAULT '',
    avatar_asset_id     TEXT,                            -- FK soft tới media_assets
    role                TEXT NOT NULL DEFAULT 'learner', -- learner | admin
    pro_tier            TEXT NOT NULL DEFAULT 'free',    -- free | pro
    pro_expires_at      TIMESTAMPTZ,                     -- NULL nếu free
    onboarding_goal     TEXT,                            -- 'a2_pobyt' | 'a2_general' | 'advanced'
    onboarding_level    TEXT,                            -- 'a0' | 'a1' | 'a2' | 'unknown'
    daily_reminder_at   TEXT,                            -- 'HH:MM' local VN, NULL = off
    push_token          TEXT,                            -- APNs/FCM
    push_token_platform TEXT,                            -- 'ios' | 'android'
    timezone            TEXT NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
    grace_attempts_left INT NOT NULL DEFAULT 3,          -- decrement đến 0 thì block tới khi verify
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ
);

CREATE UNIQUE INDEX users_email_normalized_uniq
    ON users (email_normalized) WHERE deleted_at IS NULL;
```

### 3.2 Bảng `auth_tokens` (refresh + bearer)

```sql
CREATE TABLE auth_tokens (
    token_hash       TEXT PRIMARY KEY,         -- sha256(random) — không lưu plain
    user_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind             TEXT NOT NULL,            -- 'session' | 'email_verify' | 'password_reset'
    expires_at       TIMESTAMPTZ NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at       TIMESTAMPTZ,
    last_used_at     TIMESTAMPTZ,
    user_agent       TEXT,
    ip_address       TEXT
);

CREATE INDEX auth_tokens_user_kind ON auth_tokens (user_id, kind) WHERE revoked_at IS NULL;
CREATE INDEX auth_tokens_expires ON auth_tokens (expires_at) WHERE revoked_at IS NULL;
```

TTL theo `kind`:
- `session`: 30 ngày, sliding (`last_used_at` < 7d cũ thì rotate)
- `email_verify`: 24 giờ
- `password_reset`: 1 giờ (one-shot — `revoked_at` set ngay sau dùng)

### 3.3 Bảng `streak_days`

```sql
CREATE TABLE streak_days (
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day        DATE NOT NULL,                  -- ngày local VN
    completed  BOOLEAN NOT NULL DEFAULT FALSE, -- true khi >=1 attempt completed trong ngày
    grace_used BOOLEAN NOT NULL DEFAULT FALSE, -- Pro user dùng grace pass cho ngày này
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, day)
);

CREATE INDEX streak_days_user_day ON streak_days (user_id, day DESC);
```

### 3.4 Bảng `pro_purchases` (Apple IAP receipts)

```sql
CREATE TABLE pro_purchases (
    id                TEXT PRIMARY KEY,
    user_id           TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    apple_transaction_id TEXT NOT NULL,
    apple_original_transaction_id TEXT NOT NULL,
    product_id        TEXT NOT NULL,           -- 'pro_monthly' | 'pro_yearly'
    purchased_at      TIMESTAMPTZ NOT NULL,
    expires_at        TIMESTAMPTZ NOT NULL,
    receipt_payload   JSONB NOT NULL,          -- raw verifyReceipt response
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX pro_purchases_apple_txn_uniq ON pro_purchases (apple_transaction_id);
CREATE INDEX pro_purchases_user_active ON pro_purchases (user_id) WHERE is_active = TRUE;
```

### 3.5 Bảng `daily_usage` (rate limit free tier)

```sql
CREATE TABLE daily_usage (
    user_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day              DATE NOT NULL,
    attempts_count   INT NOT NULL DEFAULT 0,
    interviews_count INT NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, day)
);
```

Reset implicit theo PRIMARY KEY (day mới = row mới).

### 3.6 FK chuyển từ `attempts.user_id` (text) sang `users.id`

V17 KHÔNG enforce FK cứng (giữ TEXT) để tránh rewrite store layer; thay vào đó middleware validate `user.id` tồn tại trong `users` table khi authenticate. Migration step:

1. Migration `023_users.sql` tạo bảng users + auth_tokens + streak_days + pro_purchases + daily_usage
2. **Production reset (one-shot)**: `TRUNCATE attempts, mock_exam_sessions, mock_exam_sections, full_exam_sessions, attempt_feedbacks, attempt_review_artifacts CASCADE` — chỉ chạy trong cutover window khi launch
3. `dev-learner-token` + `dev-learner-2-token` chỉ seed khi `ENV != production`

---

## 4. API contracts

Tất cả endpoint mới under `/v1/auth/*`. Response error theo format hiện hành: `{"error": "code", "message": "..."}`.

### 4.1 `POST /v1/auth/signup`

**Public**, no auth.

Request:
```json
{
  "email": "ban@example.com",
  "password": "min8chars1digit",
  "display_name": "Nguyễn Văn A"
}
```

Response 200:
```json
{
  "user": { "id": "u_xxx", "email": "ban@example.com", "email_verified": false, "display_name": "Nguyễn Văn A", "pro_tier": "free", "grace_attempts_left": 3 },
  "session_token": "raw_token_30d",
  "expires_at": "2026-06-03T00:00:00Z"
}
```

Errors:
- `409 email_taken` — `email_normalized` đã tồn tại (chưa soft-delete)
- `400 invalid_email` — regex không khớp
- `400 weak_password` — < 8 ký tự hoặc thiếu digit/special

Side effects:
- Insert `users` row, `password_hash = bcrypt(password, 12)`
- Insert `auth_tokens` (kind=session, 30d) + (kind=email_verify, 24h)
- Send SES email "Xác minh email" với link `https://app.<domain>/v1/auth/verify-email?token=<raw>`

### 4.2 `POST /v1/auth/login`

Request: `{ "email": "...", "password": "..." }`

Response 200: same shape as signup.

Errors:
- `401 invalid_credentials` — email hoặc password sai (không leak which)
- `429 too_many_attempts` — quá 5 lần fail/15 phút trên cùng email

### 4.3 `POST /v1/auth/logout`

Auth required (bearer). Revoke current session token (`revoked_at = NOW()`).

Response 204.

### 4.4 `GET /v1/auth/verify-email?token=<raw>`

Public. Token from email link.

- Tìm `auth_tokens` (kind=email_verify, expires_at > NOW(), revoked_at IS NULL)
- Set `users.email_verified_at = NOW()`, `grace_attempts_left = 999999`
- Revoke token
- Return HTML page "Đã xác minh — quay lại app" với deep link `czechgo://verified`

### 4.5 `POST /v1/auth/resend-verify`

Auth required. Cooldown 60s/email (rate-limit).

Response 204. Side effect: revoke pending verify token + create new + send SES.

### 4.6 `POST /v1/auth/forgot-password`

Public. Request: `{ "email": "..." }`

Response 200 always (không leak email exists). Side effect: nếu user tồn tại → create `password_reset` token (1h) + SES email.

### 4.7 `POST /v1/auth/reset-password`

Public. Request: `{ "token": "raw", "new_password": "..." }`

Response 204. Side effects:
- Validate token, update `password_hash`, revoke token
- Revoke ALL `session` tokens của user (force re-login mọi device)

### 4.8 `POST /v1/auth/change-password`

Auth required. Request: `{ "current_password": "...", "new_password": "..." }`

Errors: `401 invalid_current_password`. Side effect giống reset-password (revoke other sessions).

### 4.9 `GET /v1/users/me`

Auth required.

Response:
```json
{
  "user": { ... full users row except password_hash ... },
  "streak": { "current_days": 12, "longest_days": 28, "last_completed_day": "2026-05-03", "grace_pass_left_this_week": 1 },
  "usage_today": { "attempts": 3, "attempts_limit": 7, "interviews_this_week": 0, "interviews_limit": 1 },
  "pro": { "active": false, "expires_at": null, "product_id": null }
}
```

### 4.10 `PATCH /v1/users/me`

Auth required. Request (all fields optional):
```json
{
  "display_name": "...",
  "onboarding_goal": "a2_pobyt",
  "onboarding_level": "a1",
  "daily_reminder_at": "20:00",
  "push_token": "...",
  "push_token_platform": "ios"
}
```

### 4.11 `POST /v1/users/me/avatar`

Auth required. Multipart upload (reuse `media_assets` flow). Response trả `avatar_asset_id`.

### 4.12 `DELETE /v1/users/me`

Auth required. Soft delete: `deleted_at = NOW()`, revoke all tokens, anonymize email (`deleted_<id>@deleted.local`). **Required by App Store guideline 5.1.1(v)**.

### 4.13 `POST /v1/users/me/email-change`

Auth required. Request: `{ "new_email": "...", "current_password": "..." }`

Side effect: queue email change pending. Send verify link to **new** email. Old email nhận notification "Email đang đổi sang X". Khi click link → swap email + reset `email_verified_at`.

### 4.14 `POST /v1/iap/apple/verify`

Auth required. Request:
```json
{
  "receipt": "<base64 from StoreKit>",
  "product_id": "pro_monthly"
}
```

Backend: gọi Apple verifyReceipt (sandbox first nếu fail, fallback prod theo Apple docs). Validate `transaction_id` chưa tồn tại trong `pro_purchases`. Insert row, update `users.pro_tier='pro'` + `pro_expires_at`.

Response: `{ "pro_expires_at": "...", "is_renewing": true }`.

### 4.15 `POST /v1/iap/apple/webhook` (App Store Server Notifications V2)

No-auth (verify signature theo Apple JWS). Handle `RENEWAL` / `EXPIRED` / `REFUND`. Update `pro_purchases.is_active` + `users.pro_tier`.

### 4.16 Middleware changes

- `withAuth` thay đổi: token lookup `auth_tokens` table (sha256 hash), check `revoked_at IS NULL AND expires_at > NOW()`, load user, attach to context. Update `last_used_at`.
- New middleware `requireVerified` cho endpoints sau grace expire (apply trên `/v1/attempts` POST khi `grace_attempts_left = 0` AND `email_verified_at IS NULL`).
- New middleware `requireProOrUnderLimit` cho `/v1/attempts` (check `daily_usage` + `pro_tier`).

---

## 5. Frontend (Flutter)

### 5.1 Screens mới

Path: `flutter_app/lib/features/auth/screens/`

| File | Purpose |
|---|---|
| `welcome_screen.dart` | First impression, 2 CTA (Đăng ký / Đăng nhập) |
| `signup_screen.dart` | Form 3 field + ToS checkbox |
| `login_screen.dart` | Email + password + forgot link |
| `verify_pending_screen.dart` | Inbox illustration + Resend cooldown |
| `forgot_password_screen.dart` | Email field |
| `reset_password_screen.dart` | New + confirm (deep link entry) |
| `onboarding_screen.dart` | 3 steps (goal / level / reminder) |
| `change_password_screen.dart` | Profile → Đổi mật khẩu |
| `streak_history_screen.dart` | Calendar heatmap |
| `paywall_screen.dart` | Comparison table + IAP CTA |
| `pro_success_screen.dart` | Confirmation |

### 5.2 Auth state

`lib/core/auth/auth_service.dart` — singleton, ChangeNotifier:

```dart
class AuthService extends ChangeNotifier {
  AuthState get state; // loading | unauthenticated | authenticated | needsVerify
  User? get currentUser;
  Future<void> signup(...);
  Future<void> login(...);
  Future<void> logout();
  Future<void> refresh();
}
```

Token persisted via `flutter_secure_storage` (KeyChain iOS). Bootstrap `_loadFromStorage()` chạy trong `main()` trước `runApp`.

### 5.3 Routing change

`AppShell` (root) đọc `AuthService.state`:
- `loading` → splash
- `unauthenticated` → `WelcomeScreen`
- `authenticated` → `HomeShell` (existing 2-tab)
- `needsVerify` AND `grace_attempts_left = 0` → block với inline banner

Deep link `czechgo://verified` + `czechgo://reset?token=<raw>` cần register URL scheme trong `Info.plist`.

### 5.4 Existing screens augment

- `HomeScreen`: thêm `StreakRingWidget` top + Pro banner nếu free + verify banner nếu chưa verify
- `ProfileScreen`: thêm sections Account / Học tập (streak history) / Pro / Đăng xuất; existing locale + interview prefs giữ nguyên

### 5.5 IAP

Package: `in_app_purchase: ^3.x` (official Flutter team).

Bundle ID: `eu.hadoo.czechgo` (domain `czechgo.hadoo.eu` reversed).

Product IDs khai báo App Store Connect (auto-renewing subscription group `pro`):
- `eu.hadoo.czechgo.pro.monthly` — **placeholder** 99k VND
- `eu.hadoo.czechgo.pro.yearly` — **placeholder** 990k VND

> Pricing là **placeholder**, chốt sau A/B test với cohort early adopter. Ghi giá vào App Store Connect 1 lần để pass review; điều chỉnh qua price tier không cần resubmit binary.

Flow paywall → `InAppPurchase.instance.buyNonConsumable(...)` → callback `purchaseStream` → backend verify → success screen.

---

## 6. CMS changes

Read-only learner management (V17 không thêm CRUD admin):

- `/learners` page: thay vì derive từ `/v1/attempts`, gọi API mới `GET /v1/admin/users?limit=...` (cần thêm — return list + pagination)
- Hiện thêm cột `pro_tier`, `email_verified`, `last_seen` (max `updated_at`)
- Filter: `all | pro | free | unverified`
- KHÔNG có edit/delete admin-side V17 — defer V18 nếu cần

Endpoint: `GET /v1/admin/users` requires `withRole("admin")`.

---

## 7. Email templates (SES)

Path: `backend/internal/email/templates/`

| File | Subject | Trigger |
|---|---|---|
| `verify_email.html` | "Xác minh email Czech Go" | signup, resend, email-change |
| `password_reset.html` | "Đặt lại mật khẩu Czech Go" | forgot-password |
| `password_changed.html` | "Mật khẩu đã đổi" | reset-password, change-password (security notification) |

Format: Vietnamese primary, English fallback dưới mỗi block. Brand: orange `#FF6A14` button + cream background.

SES config required:
- Domain identity verified (DKIM + SPF)
- Suppression list cleanup hooks
- Bounce/complaint webhook → `auth_tokens` mark email invalid (block resend)

---

## 8. Security

### 8.1 Password
- bcrypt cost **12** (admin dùng 10; learner cao hơn vì lifecycle dài)
- Min 8 ký tự, must contain ≥1 digit OR ≥1 special
- Reject top-1000 common passwords (embedded list)
- No max length nhưng truncate at 72 bytes (bcrypt limit) trước hash

### 8.2 Rate limits
- Login: 5 fails/15 min/email → 429 + exponential backoff
- Signup: 10/giờ/IP
- Resend verify: 1/60s/user
- Forgot password: 3/giờ/email
- IAP verify: 30/giờ/user

In-memory token bucket V17 (single-instance backend); chuyển Redis nếu scale horizontal.

### 8.3 Token storage
- Raw token chỉ tồn tại tại moment generate + transit
- DB lưu `sha256(raw)` ở `auth_tokens.token_hash`
- Bearer token format: `Authorization: Bearer <raw>` (32 bytes random base64url, 43 chars)

### 8.4 Email verification bypass
- 3 attempts grace mode = soft enforcement
- Hard endpoints chặn ngay cả grace: `POST /v1/iap/apple/verify` (không cho mua khi chưa verify)

### 8.5 Account deletion
- Soft delete giữ `users.id` để `attempts.user_id` không broken
- Anonymize email + `display_name = '(deleted)'` + clear `avatar_asset_id`, `push_token`
- Hard delete sau 30 ngày qua cron job (defer V18)

### 8.6 PII data export
- Tuân Apple Guideline 5.1.1(v): cung cấp data export
- Endpoint `GET /v1/users/me/export` trả JSON tất cả attempts + feedback của user
- Defer auto-delete confirmation email tới V18

---

## 9. Testing strategy

### 9.1 Backend (Go)

`backend/internal/httpapi/auth_handlers_test.go`:
- `TestSignup_Success` — 200 + token + user inserted
- `TestSignup_DuplicateEmail` — 409
- `TestSignup_WeakPassword` — 400 (< 8, no digit, no special)
- `TestLogin_InvalidCredentials_NoLeakExistence` — 401 same response cho email tồn tại + password sai vs email không tồn tại
- `TestLogin_RateLimit` — 6th attempt trong 15 min → 429
- `TestVerifyEmail_HappyPath` — set verified, revoke token
- `TestVerifyEmail_ExpiredToken` — 400
- `TestForgotPassword_NonexistentEmail_ReturnsOK` — không leak
- `TestResetPassword_RevokesAllSessions`
- `TestChangePassword_RequiresCurrentPassword`
- `TestGetMe_IncludesStreakAndUsage`
- `TestGracceMode_3AttemptsThenBlock`
- `TestIAPVerify_RejectsDuplicateTransaction`
- `TestIAPWebhook_HandlesRenewal`
- `TestIAPWebhook_HandlesRefund_RevokesProActive`
- `TestStreak_TimezoneVN_DayBoundary` — 23:59 VN vs 00:01 VN cùng UTC day → khác streak day
- `TestDailyUsage_FreeUserBlockedAt7thAttempt`
- `TestDailyUsage_ProUserUnlimited`

`backend/internal/store/postgres_users_test.go`:
- CRUD round-trip
- `email_normalized` unique constraint case-insensitive
- Soft delete excludes from lookup

### 9.2 Flutter (widget + unit)

`flutter_app/test/auth/`:
- `signup_screen_test.dart` — validation per field, submit disabled khi invalid
- `login_screen_test.dart` — error display, password toggle
- `streak_ring_test.dart` — accessibility label, render 7-day dots
- `paywall_screen_test.dart` — IAP flow mock, restore purchase visible
- `auth_service_test.dart` — token persistence, refresh on 401

### 9.3 CMS (Vitest)

- `learners-dashboard-v2.test.tsx` — render new columns, filter pills

### 9.4 E2E smoke

`scripts/smoke-auth-flow.sh`:
1. signup → expect 200 + token
2. login wrong password 6 lần → expect 6th = 429
3. verify email via test endpoint (skip SES) → expect verified
4. forgot password → expect 200 (always)
5. reset password → expect old session revoked

---

## 10. Rollout

### Phase A — Backend infra (5 ngày)
1. Migration `023_users.sql` + stores + `addColumnIfMissing` pattern
2. Auth handlers + middleware swap
3. SES domain identity + DKIM (parallel)
4. Backend tests pass

### Phase B — Flutter auth UI (4 ngày)
1. AuthService + secure storage
2. Welcome / Signup / Login / Verify pending
3. Forgot / Reset password (deep link)
4. AppShell routing swap

### Phase C — Profile + Streak (3 ngày)
1. PATCH /me
2. Onboarding screens
3. StreakRing + history
4. Avatar upload

### Phase D — Paywall + IAP (4 ngày)
1. App Store Connect product setup
2. Flutter `in_app_purchase` integration
3. Backend Apple verify + webhook handler
4. Daily usage rate limit middleware
5. Paywall screen + Pro success

### Phase E — Cutover (1 ngày)
1. `ENV=production` deploy backend mới
2. Run prod data scrub script (TRUNCATE attempts/* trong cutover window)
3. Disable old dev tokens trong production
4. Monitor SES bounce + signup metric 24h

**Total estimate:** ~17 ngày làm việc full-time.

### Pre-launch checklist

- [ ] SES production access (out of sandbox)
- [ ] Apple In-App Purchase agreement signed (App Store Connect → Agreements, Tax, and Banking)
- [ ] App Privacy form filled (Apple): email, name, push token, usage data
- [ ] Privacy policy URL live (`/privacy`)
- [ ] Terms of Service URL live (`/terms`)
- [ ] Account deletion flow tested (App Store Guideline 5.1.1(v))
- [ ] Data export endpoint tested
- [ ] Rate limit tuned trên staging với load test
- [ ] DKIM/SPF verified với mail-tester.com → score ≥ 9/10

### Rollback

Nếu cutover lỗi nặng:
1. Restore Postgres snapshot từ trước cutover
2. Redeploy backend version trước (giữ image tag `pre-v17`)
3. Flutter app version cũ vẫn hoạt động vì dev token chưa scrub trong staging

---

## 11. Open questions

| # | Question | Owner | Default nếu không chốt |
|---|---|---|---|
| 1 | Pro pricing 99k/month có phù hợp VN market? | Product | **Placeholder** 99k/990k, A/B sau với early adopter cohort |
| 2 | Streak grace pass cho phép mua thêm? | Product | Không, chỉ 1/tuần Pro tier |
| 3 | Data export format (JSON only hay PDF?) | Product | JSON đủ Apple compliance |
| 4 | Tự động tải avatar từ Gravatar nếu không upload? | Eng | Không, default initials avatar |
| 5 | Push notification 8h sáng có conflict ToS Apple? | Eng | OK nếu user opt-in onboarding |

---

## 12. Boundaries

### Always do
- Hash password bcrypt cost 12 trước khi lưu
- Sha256 token trước khi lưu DB
- Validate IAP receipt server-side (không tin client)
- Streak compute server-side với `Asia/Ho_Chi_Minh` timezone
- Send security notification email khi password đổi

### Always ask first
- Thay đổi pricing (99k/990k)
- Thêm OAuth provider
- Backfill legacy attempts vào real users
- Soft → hard delete cron policy
- Mở rộng Pro features ngoài rate limit

### Never do
- Lưu plaintext password ở bất kỳ đâu (log, error, response)
- Leak email-existence qua login/forgot endpoint
- Trust client-side `pro_tier` cho gating
- Skip Apple verifyReceipt và tin client transaction_id
- Force-verify hardcoded admin để test bypass auth trong production
- Carry dev tokens (`dev-learner-token`) sang production database
- Đặt rate limit thấp hơn 1 req/giờ/IP cho signup (block legitimate users)
