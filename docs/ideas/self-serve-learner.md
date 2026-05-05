# Self-Serve Learner — Idea Refine

**Status:** Refined → ready for planning
**Date:** 2026-05-05
**Spec:** `docs/specs/self-serve-learner-spec.md`
**Plan:** `docs/plans/self-serve-learner-plan.md`

---

## Problem Statement (How Might We)

**Làm sao để học viên Việt tự đăng ký, xác minh email, luyện A2, theo dõi streak, và unlock Pro qua Apple IAP — không cần admin can thiệp, đồng thời bù chi phí LLM/Polly/ElevenLabs đang tăng theo người dùng?**

Trước slice này, hệ thống learner = `dev fixture + analytics read-only`:
- 2 dev token hardcode trong `MemoryStore.usersByToken`
- Không có bảng `users`, không có signup, không có lifecycle thật
- CMS `/learners` chỉ derive từ `attempts.user_id` (text tự do)
- Không có FK, không có ownership thực

App đã đủ tính năng (V1–V16) để launch — gating còn lại là auth + monetization.

---

## Recommended Direction

**V1 (Boring Default) + V4 streak hook làm paywall trigger.**

Lý do chọn:

1. **V1 boring email + bcrypt** — pattern admin auth đã chạy production từ V6, reuse zero novelty risk. Magic link / OTP / OAuth có thể làm sau khi auth foundation chắc.
2. **V4 streak grace pass** — Pro có exclusive value rõ rệt (badge recovery), không chỉ "unlimited attempts". Học viên đã streak 5+ ngày sẽ chi 99k để khỏi mất badge — đây là retention engine + monetization hook trong cùng một feature.
3. **Email verify grace mode (3 attempts)** — variation V2 inversion. Giảm friction signup mà vẫn chống spam thật vì attempt thứ 4 ép verify, spam bot không persist tới đó.
4. **Free 7 attempts/ngày + 1 interview/tuần** — đủ cho học viên thật self-paced; cap LLM cost ngay từ đầu thay vì trả đắt rồi mới dựng paywall.

Bỏ qua:
- **V3 ship-in-3-days** — không giải bài toán LLM cost, dễ bị spam attack vào endpoint Claude/ElevenLabs khi viral.
- **V5 parent-learner duo** — scope khác hẳn, đổi product model. Defer cho đến khi có signal phụ huynh thật.
- **V6 daily challenge leaderboard** — hay nhưng cần push notif infra + leaderboard latency. Quá đắt cho V17. Có thể slice riêng V18+.

---

## Key Assumptions to Validate

- [ ] **A1: Học viên Việt sẵn sàng nhập email + password** thay vì OTP/magic link. *Test:* Signup conversion rate ≥ 60% trong 100 visitor đầu tiên (analytics event funnel).
- [ ] **A2: Streak 5+ ngày tạo willingness-to-pay** đủ cho 99k/tháng. *Test:* Cohort 30 ngày sau launch — % user streak ≥ 5 ngày → upgrade Pro ≥ 8%.
- [ ] **A3: Apple verifyReceipt + ASSN V2** ổn định cho VN App Store region. *Test:* Sandbox + 10 real purchases trong TestFlight beta trước GA.
- [ ] **A4: SES eu-central-1 deliverability** tốt với Vietnamese inbox (Gmail/Outlook/Yahoo). *Test:* mail-tester.com ≥ 9/10, inbox placement test 50 emails (Gmail + Outlook + Yahoo + iCloud) — không vào spam.
- [ ] **A5: Rate limit 7 attempts/ngày đủ cho học viên cá nhân tự ôn**. *Test:* Đo p95 attempts/day của dev-learner-token trong 7 ngày trước launch — nếu p95 ≤ 5 thì 7 là vừa.
- [ ] **A6: Bcrypt cost 12** đủ nhanh trên backend EC2 hiện tại (≤ 250ms per hash). *Test:* Benchmark `BenchmarkBcryptCost12` trên staging EC2 instance.
- [ ] **A7: Grace mode 3 attempts không bị spam abuse** ở quy mô. *Test:* Monitor signup rate vs verified signup ratio sau 30 ngày. Nếu unverified > 50% → tăng cost (captcha hoặc giảm grace = 1).

---

## MVP Scope

**In:**
- Email + password signup/login/logout
- Bcrypt cost 12 + bearer token sha256-hashed
- Email verify (24h token) + grace 3 attempts
- Forgot/reset password (1h token, one-shot)
- Change password (revoke other sessions)
- Profile: display_name, avatar, onboarding goal/level, daily reminder time, push token
- Streak server-side timezone Asia/Ho_Chi_Minh + history calendar
- Free tier rate limit: 7 attempts/ngày + 1 interview/tuần
- Pro tier qua Apple IAP (monthly + yearly auto-renew)
- Pro perks: unlimited attempts/interview + 1 streak grace pass/tuần + mock test full
- Account deletion (Apple Guideline 5.1.1(v))
- Data export JSON (Apple Guideline 5.1.1(v))
- CMS read-only learner dashboard upgrade (pro_tier, email_verified columns)

**Out (V18+):**
- OAuth (Google/Apple Sign In)
- Android billing
- Stripe / web learner UI
- Class/cohort/teacher role
- Daily challenge leaderboard
- Auto-delete cron (30 days post soft-delete)
- Auto-Gravatar fallback
- Email change pending double-confirmation flow polish

---

## Not Doing (and Why)

- **OAuth (Google/Apple Sign In)** — Apple Sign In **bắt buộc** nếu có Google Sign In trong cùng app. Setup Apple Sign In phức tạp (Service ID + key + revocation webhook). Email + password đơn giản hơn cho V17, có thể thêm OAuth khi có signal user yêu cầu.
- **Magic link only (no password)** — Tốt UX nhưng forgot-password flow vẫn cần password fallback nếu mất email access. Email + password phổ thông hơn cho audience Việt.
- **Stripe** — Apple bắt buộc IAP cho digital subscription trong app iOS. Stripe chỉ dùng được trên web — chưa có web learner UI.
- **Backfill legacy attempts vào real users** — Semantics weird ("user signup đầu tiên ăn hết data dev-learner"). Sạch sẽ hơn là TRUNCATE trong cutover window.
- **Self-serve refund** — Apple xử lý refund qua App Store; backend chỉ handle webhook revoke Pro. Không xây refund UI.
- **Email change OTP confirmation** — Đơn giản hóa V17: gửi link sang new email + notify old email. Double-confirmation OTP defer.
- **Auto delete user data sau N ngày inactive** — GDPR-style retention defer cho khi có legal requirement rõ ràng.
- **Email-only login (no password)** — Mất password recovery path nếu user mất quyền email. Quá rủi ro.
- **In-app email reading (deep link bypass)** — Force user mở email client thật để verify → giảm bot signup automate.
- **Username thay email** — Email là canonical identity (Apple, recovery, notification). Username thêm complexity không value.
- **Password rotation / expiry** — NIST SP 800-63B đã bỏ rotation; cost UX cao, security gain thấp.
- **Multi-factor auth V17** — Defer V18 nếu có user yêu cầu hoặc breach signal. Email + password đủ cho audience học viên.

---

## Open Questions

1. **Pro pricing** — 99k monthly / 990k yearly là placeholder. Cần A/B test với cohort early adopter sau launch (baseline vs 79k vs 119k).
2. **Streak grace pass cap** — 1/tuần Pro có đủ tạo willingness-to-pay? Hay nên 2/tuần? Cần đo break rate của free user → nếu break > 30%/tuần thì 1 grace pass đã đủ value.
3. **Daily reminder time UI** — Picker giờ hay 4-preset (sáng 8h / trưa 12h / chiều 17h / tối 20h)? Preset nhanh hơn nhưng kém personalize.
4. **Avatar default** — Initials (chữ cái đầu họ tên) trên background gradient theo `users.id` hash? Hay icon học viên chung?
5. **Push notification copy** — Vietnamese? Czech learner-facing? Mix? Nếu reminder thì VI; nếu motivational ("Bạn đã streak 7 ngày rồi!") thì cũng VI.
6. **Onboarding skip persistence** — User skip onboarding → có popup nhắc sau 3 ngày không? Hay tôn trọng tuyệt đối?
7. **Account export format** — JSON đủ Apple compliance. Có cần CSV/PDF cho UX? Defer V18.
8. **Pro success animation** — Confetti có vi phạm reduced-motion guidelines không? Cần fallback static checkmark cho `prefers-reduced-motion`.

---

## Variations Considered (Phase 1 expand)

| ID | Lens | Idea | Verdict |
|---|---|---|---|
| V1 | Boring default | Email + bcrypt + verify + IAP | **CHỌN** (foundation) |
| V2 | Inversion | Verify-on-first-action grace mode | **CHỌN** (giảm friction signup) |
| V3 | Simplification | Ship-in-3-days, no verify/streak/paywall | Reject — không giải LLM cost |
| V4 | Combination | Streak break = lose badge → Pro grace pass | **CHỌN** (retention + monetization) |
| V5 | Audience shift | Parent-learner duo (phụ huynh trả) | Reject — out of product scope V17 |
| V6 | 10x scale | Daily challenge leaderboard | Defer V18+ — quá đắt infra cho V17 |

Final = **V1 + V2 (grace) + V4 (streak hook)**.

---

## Why Now

1. **LLM cost growing** — V14 interview + V15 image gen đã add Claude tokens + Replicate spend. Free unlimited là rủi ro tài chính.
2. **App Store reviewer requirements** — Submit production yêu cầu user account flow + privacy controls (delete account, data export). Không thể launch không có auth.
3. **App đủ chín** — V1–V16 đã cover skill expansion (speaking, writing, listening, reading, vocab, grammar, interview, mock test). Slice tiếp theo logically là user lifecycle + monetization, không phải skill mới.
4. **Bundle ID có sẵn** — `eu.hadoo.czechgo` (domain `czechgo.hadoo.eu`). App Store Connect setup chỉ cần thêm subscription group.
5. **AWS stack ready** — SES eu-central-1 cùng region S3 + Polly + Transcribe. Không thêm vendor.

---

## Success Metrics (đo sau launch 30 ngày)

| Metric | Target |
|---|---|
| Signup conversion (visitor → signup) | ≥ 60% |
| Email verify rate (signup → verified trong 7 ngày) | ≥ 75% |
| Day-7 retention | ≥ 35% |
| Day-30 retention | ≥ 18% |
| Free → Pro conversion (Day-30 cohort) | ≥ 8% |
| Streak ≥ 7 ngày user share | ≥ 25% |
| Apple IAP success rate | ≥ 95% |
| SES bounce rate | ≤ 2% |
| Login p95 latency | ≤ 400ms |
| Signup p95 latency (bao gồm bcrypt) | ≤ 600ms |
