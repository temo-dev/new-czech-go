# Chính sách bảo mật (Privacy Policy)

**Application:** Czech Go (A2 Mluvení Sprint)
**Bundle ID:** `czechgo.hadoo.eu`
**Operator:** TBD — placeholder, hợp pháp owner cần lấp trước App Store submit
**Last updated:** 2026-05-08
**Hosted at:** `https://czechgo.hadoo.eu/legal/privacy` (operator wires hosting)

> **Trạng thái:** bản nháp V25 — luật/operator review trước public.
> Tài liệu này tuân thủ GDPR (EU) và Luật Bảo vệ dữ liệu cá nhân
> Việt Nam (Nghị định 13/2023). Apple App Privacy declarations trong
> App Store Connect phải khớp với mục §3 phía dưới.

---

## 1. Tổng quan

Operator (sau đây "**Chúng tôi**") cam kết tôn trọng quyền riêng tư
của Người dùng. Chính sách này mô tả những dữ liệu Chúng tôi thu thập,
mục đích sử dụng, các bên thứ ba xử lý, thời gian lưu giữ, và quyền
của Người dùng. Áp dụng cho mọi cài đặt Czech Go trên iOS.

## 2. Người chịu trách nhiệm xử lý dữ liệu (Data Controller)

- **Tên:** TBD (hợp pháp owner; điền trước App Store submit)
- **Địa chỉ:** TBD
- **Email DPO / liên hệ riêng tư:** privacy@hadoo.eu (TBD)
- **Đại diện EU (nếu có):** TBD

## 3. Dữ liệu thu thập

### 3.1 Dữ liệu xác thực tài khoản

| Trường | Bắt buộc | Nguồn | Lưu ở |
|---|---|---|---|
| `email` | Có | Người dùng nhập (signup) hoặc Apple Sign-In trả về | Postgres `users.email` |
| `email_normalized` | Có | Tự sinh từ email | Postgres `users.email_normalized` |
| `password_hash` | Có (Free email signup) | Bcrypt từ password Người dùng nhập | Postgres `users.password_hash` |
| `apple_sub` | Có (Sign-in-with-Apple) | Identity token JWS từ Apple | Postgres `users.apple_sub` |
| `display_name` / `nickname` | Tùy chọn | Người dùng nhập hoặc Apple trả về (`given_name + family_name`) | Postgres `users.display_name` |
| `avatar_asset_id` | Tùy chọn | Người dùng tải lên qua Profile | Storage key (S3 hoặc local) |

**Apple "Hide my email":** Apple có thể trả về email relay dạng
`*@privaterelay.appleid.com`. Email relay này được lưu nguyên xi
như một email hợp lệ; mọi gửi mail xác thực đi qua relay tới email
gốc của Người dùng. Apple kiểm soát mapping; Chúng tôi không nắm
được email gốc.

### 3.2 Nội dung học tập

| Loại | Nguồn | Mục đích | Lưu ở |
|---|---|---|---|
| Bản ghi âm phỏng vấn (`audio recording`) | Microphone iPhone | Chấm điểm + phản hồi LLM/STT | S3 / local assets |
| Transcript phỏng vấn / nói | LLM / STT của AWS Transcribe | Chấm điểm + lưu lịch sử | Postgres `attempts`, `feedback` |
| Bài viết (`psani_*`) | Người dùng nhập | Chấm điểm LLM | Postgres `attempts.payload` |
| Đáp án nghe / đọc / từ vựng / ngữ pháp | Người dùng nhập | Chấm điểm tự động | Postgres `attempts.payload` |
| Ảnh chính tả OCR (V18.1 — handwriting) | Camera / Photo Library | OCR Czech qua Claude Vision | S3 (lưu temp 24h sau OCR) |
| Streak ngày | Tự sinh | Hiển thị tiến trình học | Postgres `streak_days` |
| Daily usage (lượt luyện / phỏng vấn hôm nay) | Tự sinh | Free-tier rate limit | Postgres `daily_usage` |

### 3.3 Dữ liệu thanh toán

| Trường | Nguồn | Mục đích | Lưu ở |
|---|---|---|---|
| `apple_transaction_id` | Apple StoreKit | Idempotent verify | Postgres `pro_purchases` |
| `apple_original_transaction_id` | Apple StoreKit | Liên kết các renewal | Postgres `pro_purchases` |
| `product_id` | Apple StoreKit | Loại gói (monthly/yearly) | Postgres `pro_purchases` |
| `purchased_at`, `expires_at` | Apple StoreKit | Tính entitlement | Postgres `pro_purchases` |
| `receipt_payload` (raw Apple receipt JSON) | Apple StoreKit | Audit + verify lại nếu cần | Postgres `pro_purchases.receipt_payload` JSONB |

**Chúng tôi KHÔNG lưu:** số thẻ tín dụng, CVV, hoặc bất kỳ thông tin
thanh toán nhạy cảm nào. Apple xử lý toàn bộ giao dịch; Chúng tôi chỉ
nhận receipt id để xác minh entitlement.

### 3.4 Dữ liệu kỹ thuật

| Trường | Nguồn | Mục đích | Lưu ở |
|---|---|---|---|
| `user_agent` | HTTP header tự nhiên | Audit log + debug | Postgres `auth_tokens.user_agent` |
| `ip_address` | HTTP socket | Rate limit + audit | Postgres `auth_tokens.ip_address` (chỉ trong session) |
| `push_token` | iOS Push Notification (nếu Người dùng cấp quyền) | Gửi nhắc giờ học | Postgres `users.push_token` |
| `timezone` | Tự sinh từ thiết bị | Tính streak theo timezone Người dùng | Postgres `users.timezone` |

### 3.5 Dữ liệu KHÔNG thu thập

- Vị trí GPS / location
- Danh bạ (contacts)
- Lịch (calendar)
- Health / fitness data
- Mạng xã hội / OAuth tokens không phải Apple
- Dữ liệu trẻ em < 13 tuổi (Người dùng phải ≥ 16; xem EULA §1)

## 4. Mục đích sử dụng

Chúng tôi xử lý dữ liệu cho các mục đích pháp lý sau (GDPR Điều 6):

1. **Hợp đồng (Article 6(1)(b))** — cung cấp dịch vụ theo thỏa thuận
   trong EULA: chấm điểm, lưu tiến trình, phát voice phỏng vấn.
2. **Lợi ích chính đáng (Article 6(1)(f))** — phòng chống lạm dụng
   (rate limit), audit log bảo mật, debug lỗi.
3. **Đồng ý (Article 6(1)(a))** — gửi push notification nhắc học (Người
   dùng cấp quyền qua iOS prompt).
4. **Nghĩa vụ pháp lý (Article 6(1)(c))** — lưu receipt giao dịch ≥ 7
   năm để khai thuế.

## 5. Bên thứ ba xử lý dữ liệu (Sub-processors)

Chúng tôi chia sẻ một số dữ liệu với các nhà cung cấp dịch vụ sau,
mỗi bên có chính sách bảo mật riêng:

| Bên thứ ba | Dữ liệu chia sẻ | Mục đích | Khu vực xử lý |
|---|---|---|---|
| **Apple Inc.** | Email, Apple sub, transaction id, receipt | StoreKit + Sign-in with Apple | Toàn cầu |
| **Anthropic (Claude API)** | Transcript phỏng vấn, bài viết, ảnh OCR | Chấm điểm + phản hồi + sinh nội dung CMS | US |
| **Amazon Web Services (AWS)** | Bản ghi âm, ảnh OCR, asset học tập | S3 (storage), Polly (TTS), Transcribe (STT), SES (email) | Singapore (ap-southeast-1) hoặc Frankfurt (eu-central-1) |
| **ElevenLabs** | Bản ghi âm phỏng vấn (chỉ trong lúc session WebSocket) | Sinh giọng nói AI cho phỏng vấn giả lập | US |
| **Replicate / Black Forest Labs** | Prompt sinh ảnh CMS (KHÔNG có dữ liệu Người dùng) | Sinh ảnh minh họa Flux | US |
| **Postgres / Database hosting** | Toàn bộ dữ liệu | Persistence | Khu vực operator chọn (TBD: AWS RDS Singapore) |

Tất cả sub-processor được chọn có chứng nhận bảo mật phù hợp (SOC 2,
ISO 27001, hoặc tương đương). Operator ký Data Processing Agreement
(DPA) với từng bên trước go-live.

## 6. Truyền dữ liệu xuyên biên giới

Một số sub-processor (Anthropic, ElevenLabs, Replicate) xử lý dữ liệu
tại Hoa Kỳ. Việc truyền dữ liệu cá nhân từ EU/Việt Nam sang US dựa
trên:

- **EU-US Data Privacy Framework** (cho EU users)
- **Standard Contractual Clauses (SCCs)** trong DPA với từng bên

Người dùng đồng ý truyền dữ liệu này khi sử dụng dịch vụ.

## 7. Thời gian lưu trữ

| Loại dữ liệu | Thời gian lưu |
|---|---|
| Tài khoản đang hoạt động | Cho đến khi Người dùng xóa tài khoản |
| Tài khoản đã xóa (soft delete) | 30 ngày để khôi phục, sau đó xóa cứng |
| Nội dung học tập (attempts, transcripts) | Cho đến khi xóa tài khoản |
| Bản ghi âm phỏng vấn | 90 ngày sau khi tạo, trừ khi Người dùng yêu cầu giữ |
| Ảnh OCR chính tả | 24 giờ sau khi xử lý |
| Receipt giao dịch (`pro_purchases`) | 7 năm (nghĩa vụ kế toán) |
| `auth_tokens` (session) | TTL 90 ngày, tự xóa khi hết hạn hoặc logout |
| Audit log (IP, user_agent) | 12 tháng |

## 8. Quyền của Người dùng

Người dùng có các quyền sau theo GDPR và Nghị định 13/2023:

### 8.1 Quyền truy cập (Right of access)

Yêu cầu bản sao dữ liệu cá nhân Chúng tôi đang lưu giữ.
**Cách thực hiện:** gửi email đến privacy@hadoo.eu — phản hồi trong 30
ngày.

### 8.2 Quyền chỉnh sửa (Right to rectification)

Sửa thông tin sai/cũ qua **Hồ sơ → Chỉnh sửa**, hoặc gửi email yêu cầu
cho thông tin không thể tự sửa.

### 8.3 Quyền xóa (Right to erasure / "right to be forgotten")

Xóa toàn bộ dữ liệu qua **Hồ sơ → Xóa tài khoản** (App Store guideline
5.1.1(v) đã tuân thủ trong V17). Yêu cầu hoàn tất trong 30 ngày.
**Ngoại lệ:** receipt giao dịch giữ 7 năm cho mục đích kế toán (luật
kế toán Việt Nam + EU).

### 8.4 Quyền hạn chế xử lý (Right to restriction)

Yêu cầu tạm dừng xử lý dữ liệu nếu Người dùng tranh chấp tính chính
xác hoặc tính hợp pháp.

### 8.5 Quyền dữ liệu di động (Right to data portability)

Yêu cầu xuất dữ liệu dạng JSON / CSV.
**Cách thực hiện:** email privacy@hadoo.eu — xuất qua S3 presigned URL
trong 30 ngày.

### 8.6 Quyền phản đối (Right to object)

Phản đối xử lý dựa trên lợi ích chính đáng. Áp dụng cho push
notification (tắt qua **Hồ sơ → Thông báo**).

### 8.7 Quyền rút lại đồng ý (Right to withdraw consent)

Rút lại đồng ý đã cấp (push token, OCR ảnh chính tả) bất cứ lúc nào
qua **Cài đặt iOS → Czech Go → Quyền** hoặc trong app.

### 8.8 Quyền khiếu nại

Khiếu nại đến cơ quan giám sát dữ liệu:
- **EU:** cơ quan bảo vệ dữ liệu của quốc gia cư trú
- **Việt Nam:** Cục An toàn thông tin (Bộ Thông tin và Truyền thông)

## 9. Bảo mật dữ liệu

Chúng tôi áp dụng các biện pháp bảo mật:

- Mã hóa truyền (TLS 1.2+) cho mọi traffic API
- Mã hóa khi lưu (AES-256) tại AWS S3 + RDS
- Mật khẩu bcrypt với cost factor ≥ 12
- Session token băm SHA-256 trước khi lưu DB (raw token chỉ tồn tại
  trong response)
- Phân quyền tối thiểu (least privilege) cho mọi service account
- Audit log mọi thay đổi cấu trúc dữ liệu (migration log)
- Backup cơ sở dữ liệu hàng ngày, retention 30 ngày
- Penetration test định kỳ (operator schedule)

**Thông báo vi phạm:** trong trường hợp data breach, Chúng tôi sẽ
thông báo cho Người dùng bị ảnh hưởng và cơ quan giám sát trong vòng
**72 giờ** kể từ khi phát hiện (theo GDPR Điều 33).

## 10. Cookies + analytics

- **Ứng dụng iOS:** không sử dụng cookies (không phải web).
- **Analytics nội bộ:** chỉ thu thập số liệu thống kê đã ẩn danh
  (số lượng learner active, distribution điểm) — không có
  identifier cá nhân.
- **Không** dùng tracking SDK của bên thứ ba (Google Analytics,
  Facebook Pixel, etc.) trong giai đoạn V25.

## 11. Trẻ em

Ứng dụng không dành cho trẻ em dưới 16 tuổi. Chúng tôi không cố tình
thu thập dữ liệu trẻ em < 16. Nếu phát hiện tài khoản trẻ em, chúng
tôi xóa trong 7 ngày.

## 12. Sửa đổi chính sách

Operator có quyền sửa đổi chính sách. Thay đổi quan trọng được thông
báo qua email + push 30 ngày trước hiệu lực. Việc tiếp tục sử dụng
sau hiệu lực mới đồng nghĩa với việc chấp nhận.

## 13. Liên hệ

- **Email DPO / privacy:** privacy@hadoo.eu (TBD)
- **Email hỗ trợ chung:** support@hadoo.eu (TBD)
- **Khiếu nại EU:** cơ quan bảo vệ dữ liệu địa phương
- **Khiếu nại VN:** Cục An toàn thông tin

---

## English version

This Privacy Policy describes how Czech Go ("the App") collects, uses,
and shares personal data, in compliance with GDPR (EU) and
Decree 13/2023 (Vietnam).

### What we collect

- **Account:** email (or Apple "Hide my email" relay), bcrypt
  password hash (email signup only), Apple `sub` (Sign-in-with-Apple),
  optional display name + avatar.
- **Learning content:** voice recordings (mic), transcripts, written
  answers, OCR images of handwritten dictation, attempt history,
  streak counters, daily usage counters.
- **Payment:** Apple transaction id + receipt payload (NEVER credit
  card details — Apple handles all payment).
- **Technical:** user-agent, IP (in session only), push token (with
  consent), timezone.

We do **NOT** collect: GPS, contacts, calendar, health data,
non-Apple OAuth tokens, or data from children under 16.

### Sub-processors

Apple (StoreKit, Sign-in), Anthropic (Claude scoring), AWS (Polly,
Transcribe, S3, SES — Singapore or Frankfurt regions), ElevenLabs
(interview voice — US), Replicate / Black Forest Labs (image gen —
US, NO user data sent).

### Cross-border transfers

Some processing happens in the US. We rely on the EU-US Data Privacy
Framework and Standard Contractual Clauses (SCCs).

### Retention

Account data: until deletion. Voice recordings: 90 days. OCR images:
24 hours after processing. Receipts: 7 years (accounting law). Audit
logs: 12 months.

### Your rights

GDPR-equivalent: access, rectification, erasure, restriction,
portability, objection, withdrawal of consent, complaint to
supervisory authority. Email privacy@hadoo.eu — response within 30
days. Account deletion exposed in-app via **Profile → Delete Account**
(App Store guideline 5.1.1(v) compliant).

### Security

TLS 1.2+, AES-256 at rest, bcrypt cost ≥ 12, SHA-256 hashed session
tokens, least-privilege service accounts, daily backups (30-day
retention), 72-hour breach notification.

### Children

Not for users under 16. Accounts identified as belonging to
children are deleted within 7 days.

### Contact

- DPO / privacy: privacy@hadoo.eu (TBD)
- Support: support@hadoo.eu (TBD)
- Complaints: local DPA (EU) or Cục An toàn thông tin (VN)

### Updates

Material changes notified via email + push 30 days before
effective date. Continued use = acceptance.
