# Plan: Admin Login Feature

## Current State (baseline)

- **Backend** `handleLogin` + `withRole("admin",...)` tồn tại nhưng:
  - Credentials hardcoded: email `admin@example.com` / password `demo123`
  - Token static: `"dev-admin-token"` (không có expiry, không random)
  - `UserByToken` = simple map lookup
- **CMS** middleware dùng HTTP Basic Auth (`CMS_BASIC_AUTH_USER` / `CMS_BASIC_AUTH_PASSWORD`)
- **CMS proxy routes** gửi `Authorization: Bearer dev-admin-token` hardcoded (`CMS_ADMIN_TOKEN` env var)
- Không có login page, không có token expiry, không có env-configured credentials

## Goal

Admin có thể đăng nhập vào CMS bằng form email/password thực sự.
Tất cả `/v1/admin/*` backend routes được bảo vệ bằng token thực.

## Assumptions

1. **Single admin user** — credentials qua env vars (`ADMIN_EMAIL`, `ADMIN_PASSWORD`), không cần DB users table
2. **Opaque token** (random 32-byte hex, không JWT) — đơn giản nhất, không cần dependency ngoài
3. **HTTP-only cookie** lưu token trong CMS browser session — Next.js middleware đọc được, bảo mật hơn localStorage
4. **Learner auth** không thay đổi — Flutter app vẫn dùng `dev-learner-token` trong dev
5. **Dev fallback** — nếu `ADMIN_EMAIL`/`ADMIN_PASSWORD` unset, fall back về `admin@example.com`/`demo123` để local dev vẫn chạy

## Dependency Graph

```
A1 (backend secure token) ──┐
                             ├──→ A4 (CMS proxy dùng token từ cookie)
A2 (CMS login page) ────────┘
      │
      └──→ A3 (CMS middleware redirect to /login)
```

Thứ tự triển khai: **A1 → A2 → A3 → A4**

## Slice A1 — Backend: env-configured credentials + secure token generation

**Files:** `backend/internal/store/memory.go`, `backend/main.go`

**Changes:**
- `Login(email, password)` đọc credentials từ env: `ADMIN_EMAIL` + `ADMIN_PASSWORD`
  - Fall back về `admin@example.com`/`demo123` nếu env unset (dev mode)
- Thay `"dev-admin-token"` bằng `crypto/rand` 32-byte hex token
- Token có TTL 24h — `UserByToken` check expiry
- Khởi tạo: `"dev-admin-token"` vẫn hợp lệ nếu `ADMIN_PASSWORD` unset (dev compat)
- `"dev-learner-token"` giữ nguyên, không thay đổi

**Acceptance Criteria:**
- `POST /v1/auth/login {"email":"admin@example.com","password":"demo123"}` → `200 {access_token: "<random-hex>"}` (local dev)
- Wrong password → `401`
- Token trong response khác nhau mỗi lần login
- `GET /v1/admin/exercises` với token hợp lệ → `200`
- `GET /v1/admin/exercises` không có token → `401`

**Verification:** `make backend-build && make backend-test`

---

## Slice A2 — CMS: login page + auth API routes

**Files mới:**
- `cms/app/login/page.tsx` — form email/password, POST to `/api/auth/login`
- `cms/app/api/auth/login/route.ts` — proxy đến backend `POST /v1/auth/login`, set HTTP-only cookie `admin_token`
- `cms/app/api/auth/logout/route.ts` — clear cookie, redirect đến `/login`

**Design: Login page**
- Tái sử dụng màu sắc từ design system: orange `#FF6A14`, cream `#FBF3E7`, teal `#0F3D3A`
- Form: Email input + Password input + "Đăng nhập" button
- Error state: hiển thị "Email hoặc mật khẩu không đúng" khi backend trả 401
- Loading state: disable button khi đang POST
- Redirect về `/` sau khi thành công

**Design: API route `/api/auth/login`**
```
POST /api/auth/login {email, password}
  → POST backend /v1/auth/login
  → set cookie: admin_token=<access_token>; HttpOnly; SameSite=Strict; Max-Age=86400
  → return {ok: true}
```

**Acceptance Criteria:**
- Truy cập `/login` → form render
- Submit đúng creds → cookie set, redirect về `/`
- Submit sai creds → error message hiển thị, không redirect

**Verification:** `make cms-lint && make cms-build`

---

## Slice A3 — CMS: thay Basic Auth middleware bằng cookie guard

**Files:** `cms/middleware.ts`

**Changes:**
- Xóa `parseBasicAuth` + Basic Auth logic
- Check cookie `admin_token` thay thế
- Nếu không có cookie → redirect đến `/login`
- Exclude paths: `/login`, `/api/auth/login`, `/api/auth/logout`, `/api/healthz`, `/_next/*`
- Remove env vars `CMS_BASIC_AUTH_USER`, `CMS_BASIC_AUTH_PASSWORD`

**Acceptance Criteria:**
- Truy cập `/` không có cookie → redirect đến `/login`
- Truy cập `/` có `admin_token` cookie → page load bình thường
- `/login` không bị redirect loop

**Verification:** `make cms-build`

---

## Slice A4 — CMS: thread token từ cookie qua backend proxy

**Files:** Tất cả `cms/app/api/admin/*/route.ts`

**Changes:**
- Thêm helper `cms/lib/auth.ts`: `getAdminToken(request: NextRequest): string`
  - Đọc `request.cookies.get('admin_token')?.value`
  - Fall back về `process.env.CMS_ADMIN_TOKEN ?? 'dev-admin-token'` (dev compat)
- Tất cả proxy routes dùng `getAdminToken(request)` thay vì hardcoded `adminToken` module-level const
- Xóa `const adminToken = process.env.CMS_ADMIN_TOKEN ?? ...` khỏi từng route file

**Files cần update (15 proxy routes):**
- `cms/app/api/admin/exercises/route.ts` + `[exerciseId]/route.ts` + các sub-routes
- `cms/app/api/admin/courses/route.ts` + `[courseId]/route.ts`
- `cms/app/api/admin/modules/route.ts` + `[moduleId]/route.ts`
- `cms/app/api/admin/skills/route.ts` + `[skillId]/route.ts`
- `cms/app/api/admin/mock-tests/route.ts` + `[mockTestId]/route.ts`
- `cms/app/api/admin/vocabulary-sets/route.ts` + `[setId]/route.ts`
- `cms/app/api/admin/grammar-rules/route.ts` + `[ruleId]/route.ts`
- `cms/app/api/admin/content-generation-jobs/route.ts` + `[jobId]/route.ts`
- `cms/app/api/admin/attempts/route.ts`

**Acceptance Criteria:**
- Sau khi login, tất cả CMS CRUD operations hoạt động
- Backend trả `401` nếu cookie bị xóa rồi thử lại API
- Không còn hardcoded `dev-admin-token` trong proxy routes

**Verification:** `make cms-lint && make cms-build`

---

## [CHECKPOINT A] — Admin Login Feature Complete

**Điều kiện pass:**
- [ ] Admin login via `/login` page, redirect về `/` sau login thành công
- [ ] Sai credentials → error message, không redirect
- [ ] Tất cả CMS CRUD routes hoạt động với token từ cookie
- [ ] Backend admin routes trả `401` khi không có token
- [ ] `make verify` green

**Env vars mới cần document:**
```
ADMIN_EMAIL=admin@example.com   # optional, default: admin@example.com
ADMIN_PASSWORD=<strong-secret>  # required in production
```

**Env vars bị xóa:**
```
CMS_BASIC_AUTH_USER     # removed
CMS_BASIC_AUTH_PASSWORD # removed
```

**Env vars giữ nguyên (backward compat):**
```
CMS_ADMIN_TOKEN         # still works as fallback in dev (A4 helper)
```
