# Self-Serve Learner — Implementation Plan

**Status:** Ready to start
**Date:** 2026-05-05
**Spec:** `docs/specs/self-serve-learner-spec.md`
**Idea:** `docs/ideas/self-serve-learner.md`

Total estimate: **~17 ngày làm việc full-time** (1 dev). Có thể parallel Backend + iOS sau Phase A.

---

## Dependency Graph

```
Phase A (Backend infra)
    ├──► Phase B (Flutter auth UI)
    │       └──► Phase C (Profile + Streak)
    │               └──► Phase D (Paywall + IAP)
    │                       └──► Phase E (Cutover)
    └──► SES domain identity (parallel, không block code)
```

Phase A là critical path — không Phase nào start được trước khi auth handler + DB schema xong.

---

## Phase A — Backend Infra (5 ngày)

### A1 — Migration + stores (1 ngày)

**Files:**
- `backend/internal/store/migrations/023_users.sql` — CREATE TABLE users + auth_tokens + streak_days + pro_purchases + daily_usage
- `backend/internal/store/postgres_users.go` — `UserStore` interface + Postgres impl
- `backend/internal/store/postgres_auth_tokens.go` — `AuthTokenStore` interface + Postgres impl
- `backend/internal/store/postgres_streak.go` — `StreakStore` interface + Postgres impl
- `backend/internal/store/postgres_pro_purchases.go` — `ProPurchaseStore` interface + Postgres impl
- `backend/internal/store/postgres_daily_usage.go` — `DailyUsageStore` interface + Postgres impl
- `backend/internal/store/memory.go` — Add memory impls cho test parity
- `backend/internal/store/postgres_migrate.go` — Add `addColumnIfMissing` cho cột mới (handle RDS owner caveat từ V11)

**Acceptance:**
- [ ] Migration chạy clean trên local Postgres
- [ ] Migration idempotent (chạy lần 2 không lỗi)
- [ ] Round-trip CRUD test cho mọi store pass
- [ ] `email_normalized` unique constraint case-insensitive
- [ ] `users_email_normalized_uniq` partial index không apply cho soft-deleted
- [ ] `make backend-test` pass

### A2 — Auth handlers (2 ngày)

**Files:**
- `backend/internal/httpapi/auth_handlers.go` — signup, login, logout, verify-email, resend-verify, forgot, reset, change-password
- `backend/internal/httpapi/users_me_handlers.go` — GET /me, PATCH /me, POST /me/avatar, DELETE /me, POST /me/email-change
- `backend/internal/httpapi/auth_middleware.go` — Replace `withAuth`: lookup `auth_tokens` table sha256, attach user to context
- `backend/internal/httpapi/rate_limit.go` — Token bucket per (email, IP, endpoint)
- `backend/internal/auth/bcrypt.go` — Hash + verify wrappers, cost 12
- `backend/internal/auth/tokens.go` — Generate raw token + sha256 hash + base64url encoding (32 bytes)
- `backend/internal/auth/password_policy.go` — Min 8, ≥1 digit OR ≥1 special, top-1000 reject
- `backend/internal/email/ses_client.go` — AWS SES SendEmail wrapper
- `backend/internal/email/templates/verify_email.html` + `password_reset.html` + `password_changed.html`

**Acceptance:**
- [ ] All 14 endpoints (§4 spec) return correct status + payload
- [ ] Login không leak email-existence (same response cho wrong email vs wrong password)
- [ ] Forgot password 200 always
- [ ] Reset password revoke all sessions
- [ ] Rate limit 5 login fails/15min/email → 429
- [ ] Bcrypt cost 12, hash p95 ≤ 250ms trên dev machine
- [ ] Token persisted as sha256 hash, raw token chỉ trong response
- [ ] `make backend-test` pass với 17+ test cases (§9.1 spec)

### A3 — Authorization gates (1 ngày)

**Files:**
- `backend/internal/httpapi/server.go` — Wrap existing `/v1/attempts` POST với `requireProOrUnderLimit` middleware
- `backend/internal/httpapi/usage_middleware.go` — Check `daily_usage` + `users.pro_tier` + decrement counter
- `backend/internal/httpapi/server.go` — Wrap `/v1/interview-sessions/token` với weekly interview limit
- `backend/internal/processing/processor.go` — Update `attempts.user_id` write path: deref từ middleware-attached user, không tin client field

**Acceptance:**
- [ ] Free user attempt thứ 8 trong ngày → 429 với header `X-Limit-Reset`
- [ ] Pro user vô hạn (test với `pro_tier='pro'` + `pro_expires_at` future)
- [ ] Pro user expired → fall back free limit
- [ ] Interview free user lần 2/tuần → 429
- [ ] `attempts.user_id` không thể spoof từ client (stripped)

### A4 — Apple IAP integration (1 ngày)

**Files:**
- `backend/internal/iap/apple_verify.go` — Call `/verifyReceipt` (sandbox first, fallback prod)
- `backend/internal/iap/apple_webhook.go` — App Store Server Notifications V2 (verify JWS, parse `notificationType`)
- `backend/internal/httpapi/iap_handlers.go` — POST /v1/iap/apple/verify + POST /v1/iap/apple/webhook
- Config: `APPLE_SHARED_SECRET` env var, `APPLE_BUNDLE_ID=eu.hadoo.czechgo`

**Acceptance:**
- [ ] verifyReceipt path test với mock HTTP server
- [ ] Duplicate `transaction_id` → 409
- [ ] Webhook RENEWAL → extend `pro_expires_at`
- [ ] Webhook EXPIRED → set `is_active=false`, `users.pro_tier='free'`
- [ ] Webhook REFUND → revoke Pro + send notification email
- [ ] JWS signature validation chạy (test với Apple sample payload)

### A5 — SES production access (parallel, không block dev)

**Tasks (manual, không phải code):**
- [ ] Verify domain `hadoo.eu` trong SES eu-central-1
- [ ] Generate DKIM keys, add CNAME to DNS
- [ ] Add SPF: `v=spf1 include:amazonses.com ~all`
- [ ] Submit production access request (out of sandbox)
- [ ] Test với mail-tester.com → score ≥ 9/10
- [ ] Inbox placement test 50 emails (Gmail, Outlook, Yahoo, iCloud) — không vào spam
- [ ] Set up bounce + complaint webhook → endpoint `/v1/internal/ses-webhook` (TODO Phase B)

---

## Phase B — Flutter Auth UI (4 ngày)

### B1 — AuthService + secure storage (1 ngày)

**Files:**
- `flutter_app/lib/core/auth/auth_service.dart` — ChangeNotifier singleton, AuthState enum
- `flutter_app/lib/core/auth/auth_storage.dart` — `flutter_secure_storage` wrapper (KeyChain iOS)
- `flutter_app/lib/core/auth/auth_models.dart` — `User`, `AuthSession` models
- `flutter_app/lib/core/api/api_client.dart` — Inject `Authorization: Bearer <token>` từ AuthService

**Acceptance:**
- [ ] Token persist qua app restart (KeyChain)
- [ ] 401 response → AuthService auto logout + emit state change
- [ ] Bootstrap `_loadFromStorage()` chạy trong `main()` trước `runApp`
- [ ] Unit test `auth_service_test.dart` pass

### B2 — Welcome / Signup / Login (1.5 ngày)

**Files:**
- `flutter_app/lib/features/auth/screens/welcome_screen.dart`
- `flutter_app/lib/features/auth/screens/signup_screen.dart`
- `flutter_app/lib/features/auth/screens/login_screen.dart`
- `flutter_app/lib/features/auth/widgets/auth_text_field.dart` — Material outlined input + autofill hints
- `flutter_app/lib/features/auth/widgets/password_strength_meter.dart`
- `flutter_app/lib/features/auth/widgets/password_visibility_toggle.dart`

**Acceptance:**
- [ ] Email + password validation on blur (không validate on keystroke)
- [ ] Submit disabled khi invalid
- [ ] First invalid field auto-focus sau submit error
- [ ] Password show/hide toggle với accessibility label
- [ ] Strength meter 4 step (weak/fair/good/strong)
- [ ] iOS keyboard type đúng (`emailAddress`, `newPassword`)
- [ ] Widget tests pass

### B3 — Verify pending + Forgot/Reset password (1 ngày)

**Files:**
- `flutter_app/lib/features/auth/screens/verify_pending_screen.dart` — 60s cooldown resend
- `flutter_app/lib/features/auth/screens/forgot_password_screen.dart`
- `flutter_app/lib/features/auth/screens/reset_password_screen.dart` — Deep link entry
- `flutter_app/ios/Runner/Info.plist` — Register URL scheme `czechgo://`
- `flutter_app/lib/core/deep_links/deep_link_handler.dart` — Parse `czechgo://verified` + `czechgo://reset?token=...`

**Acceptance:**
- [ ] Resend cooldown đếm chính xác 60s
- [ ] Forgot password trả 200 cho mọi email
- [ ] Reset password → redirect Login
- [ ] Deep link verified mở app + show success toast
- [ ] Test deep link bằng `xcrun simctl openurl booted czechgo://verified`

### B4 — AppShell routing (0.5 ngày)

**Files:**
- `flutter_app/lib/features/shell/app_shell.dart` — Replace existing với AuthService listener
- `flutter_app/lib/core/auth/auth_state_router.dart`

**Acceptance:**
- [ ] `loading` → splash
- [ ] `unauthenticated` → Welcome
- [ ] `authenticated` → existing HomeShell
- [ ] `needsVerify` AND grace=0 → block với verify banner
- [ ] State change animate smooth (200ms fade)
- [ ] Logout clear stack về Welcome

---

## Phase C — Profile + Streak (3 ngày)

### C1 — Profile section refactor (1 ngày)

**Files:**
- `flutter_app/lib/features/profile/screens/profile_screen.dart` — Augment với sections Account / Học tập / Pro / Đăng xuất
- `flutter_app/lib/features/profile/screens/change_password_screen.dart`
- `flutter_app/lib/features/profile/screens/email_change_screen.dart`
- `flutter_app/lib/features/profile/widgets/profile_section.dart`
- `flutter_app/lib/features/profile/widgets/avatar_picker.dart` — `image_picker` + crop + upload to `/v1/users/me/avatar`

**Acceptance:**
- [ ] Display name editable inline
- [ ] Avatar upload + preview
- [ ] Logout confirm dialog
- [ ] Existing locale + interview prefs giữ nguyên (không break)
- [ ] Account deletion với double-confirm dialog

### C2 — Onboarding 3 steps (1 ngày)

**Files:**
- `flutter_app/lib/features/auth/screens/onboarding_screen.dart`
- `flutter_app/lib/features/auth/widgets/onboarding_step.dart`
- `flutter_app/lib/features/auth/widgets/progress_dots.dart`
- `flutter_app/lib/features/auth/widgets/time_picker_field.dart` — Daily reminder time

**Acceptance:**
- [ ] Skip button top-right mọi step
- [ ] Progress dots animate smooth
- [ ] Submit cuối cùng PATCH /v1/users/me
- [ ] Skip → redirect Home với defaults
- [ ] Test reminder time picker output `HH:MM` format

### C3 — Streak ring + history (1 ngày)

**Files:**
- `flutter_app/lib/features/home/widgets/streak_ring_widget.dart`
- `flutter_app/lib/features/home/screens/streak_history_screen.dart` — Calendar heatmap
- `flutter_app/lib/features/home/widgets/calendar_heatmap.dart`
- `flutter_app/lib/features/home/screens/home_screen.dart` — Augment top với StreakRing + Pro banner

**Acceptance:**
- [ ] StreakRing render 7 dots (last 7 days)
- [ ] Spring animation khi tick lên (~280ms)
- [ ] Tap → Streak history
- [ ] History calendar 12 tuần gần nhất
- [ ] Pro user thấy "1 grace pass còn lại tuần này"
- [ ] Reduced motion → static, không spring
- [ ] Accessibility label: "12 ngày liên tục"

---

## Phase D — Paywall + IAP (4 ngày)

### D1 — App Store Connect setup (0.5 ngày, parallel)

**Tasks (manual):**
- [ ] Tạo App Store Connect record (Bundle ID `eu.hadoo.czechgo`)
- [ ] Subscription group `pro` với 2 tier:
  - `eu.hadoo.czechgo.pro.monthly` — placeholder 99k VND
  - `eu.hadoo.czechgo.pro.yearly` — placeholder 990k VND
- [ ] Subscription terms + privacy URL fill
- [ ] App Store Server Notifications V2 endpoint `https://api.czechgo.hadoo.eu/v1/iap/apple/webhook`
- [ ] Generate `APPLE_SHARED_SECRET` (App-Specific Shared Secret)
- [ ] Sandbox tester account tạo

### D2 — Flutter IAP integration (1.5 ngày)

**Files:**
- `flutter_app/pubspec.yaml` — Add `in_app_purchase: ^3.x`
- `flutter_app/lib/features/paywall/services/iap_service.dart`
- `flutter_app/lib/features/paywall/screens/paywall_screen.dart`
- `flutter_app/lib/features/paywall/screens/pro_success_screen.dart`
- `flutter_app/lib/features/paywall/widgets/pro_comparison_table.dart`
- `flutter_app/lib/features/paywall/widgets/restore_purchase_button.dart` (Apple bắt buộc)

**Acceptance:**
- [ ] Paywall show product price từ StoreKit (không hardcode)
- [ ] Toggle monthly/yearly với savings badge
- [ ] Buy flow → StoreKit sheet → backend verify → success screen
- [ ] Restore purchase button ở footer
- [ ] Pending transaction cleanup
- [ ] Sandbox test: 5 mua thành công
- [ ] TestFlight beta: 10 real purchases (giá thật, refund qua Apple)

### D3 — Backend IAP polish (1 ngày)

**Files:**
- `backend/internal/iap/apple_verify.go` — Production hardening (retry, timeout, logging)
- `backend/internal/iap/apple_webhook.go` — Idempotency cho duplicate webhook
- `backend/internal/iap/notification_email.go` — Send "Cảm ơn đã upgrade" + "Pro hết hạn" emails

**Acceptance:**
- [ ] Webhook idempotent (cùng `notificationUUID` xử lý 1 lần)
- [ ] Refund webhook → revoke Pro + email notification
- [ ] Renewal failure GRACE PERIOD logic (Apple cấp 16 ngày)
- [ ] Test với Apple sample payload (RENEWAL, EXPIRED, REFUND, GRACE_PERIOD)

### D4 — Daily usage rate limit polish (1 ngày)

**Files:**
- `backend/internal/httpapi/usage_middleware.go` — Tune từ A3
- `flutter_app/lib/features/home/widgets/usage_quota_indicator.dart` — Hiển thị "3/7 attempts hôm nay"
- `flutter_app/lib/features/exercise/widgets/upgrade_prompt_dialog.dart` — Khi 429 từ backend

**Acceptance:**
- [ ] Quota indicator update sau mỗi attempt
- [ ] 429 từ backend → modal "Đã hết attempts free, nâng cấp Pro?"
- [ ] Modal CTA → Paywall
- [ ] Pro user không thấy quota indicator (hide)

---

## Phase E — Cutover (1 ngày)

### E1 — Pre-cutover checklist (0.5 ngày)

- [ ] SES production access approved (out of sandbox)
- [ ] Apple IAP agreement signed
- [ ] App Privacy form filled (email, name, push token, usage data)
- [ ] Privacy policy URL `czechgo.hadoo.eu/privacy` live
- [ ] ToS URL `czechgo.hadoo.eu/terms` live
- [ ] Account deletion + data export tested manual
- [ ] Backup Postgres snapshot pre-cutover
- [ ] Rollback image tag `pre-v17` ready
- [ ] CMS deploy với new `/learners` page
- [ ] Flutter build TestFlight ổn định 48h beta

### E2 — Cutover window (0.5 ngày)

**Sequence:**
1. Backup Postgres snapshot (`pg_dump` to S3)
2. Maintenance mode: backend trả 503 cho non-admin endpoints (5 phút)
3. Run scrub script: `TRUNCATE attempts, mock_exam_sessions, mock_exam_sections, full_exam_sessions, attempt_feedbacks, attempt_review_artifacts CASCADE`
4. Run migration `023_users.sql`
5. Deploy backend image `v17.0.0`
6. Disable maintenance mode
7. Smoke test: signup → verify → login → attempt → success
8. Push Flutter v17.0.0 lên App Store production
9. Monitor 24h:
   - SES bounce rate
   - Signup rate vs verified rate
   - Login p95 latency
   - Attempt 429 rate
   - IAP purchase success rate

### Rollback trigger conditions

Nếu gặp một trong các điều kiện sau trong 24h đầu → rollback:
- SES bounce > 10%
- Login p95 > 1s
- Signup error rate > 5%
- IAP verify error rate > 10%
- Database connection saturation
- Critical bug user-blocking

**Rollback steps:**
1. Restore Postgres snapshot pre-cutover
2. Redeploy backend image `pre-v17`
3. Pull Flutter v17.0.0 khỏi App Store (revert tới version trước)
4. Post-mortem trong 48h

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| SES sandbox không out kịp launch | Medium | High | Submit production access ngay tuần 1 |
| Apple IAP review reject | Medium | High | Privacy policy + ToS sẵn sàng + account delete tested |
| Bcrypt cost 12 quá chậm trên EC2 | Low | Medium | Benchmark sớm Phase A2; fallback cost 10 nếu p95 > 500ms |
| Spam signup botnet | Medium | Medium | Grace 3 attempts + rate limit IP/giờ + email verify gate |
| Streak timezone bugs | Medium | Low | Comprehensive test với DST edge case (VN không DST nhưng test UTC boundary) |
| User mất email access không reset được | Low | Medium | V18 thêm support email manual recovery |
| Apple ASSN webhook bị miss | Low | High | Webhook idempotent + daily reconciliation cron job (Phase F V18) |
| Free tier 7/ngày quá ít | Medium | Medium | Monitor bounce rate; tăng tới 10 nếu drop > 30% |

---

## Verification

Trước khi đóng từng Phase:

| Phase | Verification |
|---|---|
| A | `make backend-test` pass + smoke-auth-flow.sh xanh |
| B | `make flutter-analyze` + `make flutter-test` pass + manual signup/login trên device |
| C | Manual test profile edit + onboarding skip + streak tick |
| D | Sandbox IAP 5 mua thành công + webhook test với Apple sample |
| E | 24h post-cutover monitoring metrics OK + zero rollback trigger |

Final gate: `make verify` pass + smoke `make smoke-all` xanh.

---

## Post-Launch (V18 candidates)

- OAuth (Google + Apple Sign In) — nếu có signal user yêu cầu
- Android billing (cần Android build trước)
- Stripe + web learner UI — nếu mở rộng platform
- Class/cohort feature
- Daily challenge leaderboard
- Auto-delete inactive user data sau 365 ngày
- Email change OTP double-confirmation
- MFA (TOTP)
- Magic link login alternative
- Push notification daily reminder gửi đúng giờ user chọn
