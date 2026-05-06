# Admin User Management Spec (V17.1)

**Status:** ✅ Implemented 2026-05-05
**Depends on:** V17 self-serve auth (`docs/specs/self-serve-learner-spec.md`)
**Idea:** [`docs/ideas/admin-user-management.md`](../ideas/admin-user-management.md)

## Goal

Admin (legacy `dev-admin-token` hoặc V17 admin session) có thể list, xoá, và đặt lại mật khẩu của tài khoản học viên từ CMS — không cần SSH backend hoặc query DB tay.

## Non-Goals

- Admin tạo learner mới (vẫn chỉ self-serve)
- Admin sửa email / display_name / role / pro_tier
- Email password-reset link tự động (self-serve learner đã có)
- Bulk operations
- Hard delete (defer V18 nếu cần GDPR cron)

## Architecture

```
CMS UI (/users)
   │
   ├── GET  /api/admin/users              → backend GET  /v1/admin/users
   ├── DELETE /api/admin/users/:id        → backend DELETE /v1/admin/users/:id
   └── POST /api/admin/users/:id/reset-password
                                          → backend POST /v1/admin/users/:id/reset-password
```

Các route CMS proxy thread `admin_token` cookie qua `lib/auth.getAdminToken()`. Backend dùng `withRole("admin")` cho cả 3 endpoint — sub-resource (`reset-password`) dispatch trong `handleAdminUserByID` dựa vào path suffix sau `:id`.

## Data Model

Không thêm bảng mới. Reuse:

| Bảng | Cột liên quan | Hành động |
|---|---|---|
| `users` | `email`, `email_normalized`, `display_name`, `avatar_asset_id`, `push_token`, `password_hash`, `deleted_at` | Mutate qua `UpdateUser` + `SoftDeleteUser` |
| `auth_tokens` | `revoked_at` | Mutate qua `RevokeAllAuthTokensForUser` (delete) hoặc `RevokeAllAuthTokensByKind(.., session)` (reset password) |

`UserStore` interface thêm 1 method:

```go
ListUsers(opts ListUsersOptions) ([]contracts.UserAccount, int, error)

type ListUsersOptions struct {
    Limit  int    // default 50, max 200
    Offset int
    Search string // case-insensitive substring of email + display_name
    Role   string // exact match, "" = no filter
}
```

Trả về `(users, total, err)` — total dùng cho pagination footer.

## Endpoints

### GET /v1/admin/users

Query params:
- `limit` (default 50, max 200)
- `offset` (default 0)
- `search` (optional)
- `role` (optional, e.g. `learner`)

Response 200:
```json
{
  "data": [
    {
      "id": "u_e330f213007ba960",
      "email": "anh.ngt18@gmail.com",
      "email_verified": false,
      "display_name": "tuan anh",
      "role": "learner",
      "pro_tier": "free",
      "grace_attempts_left": 3,
      "created_at": "2026-05-05T12:12:06Z",
      "updated_at": "2026-05-05T12:12:06Z"
    }
  ],
  "meta": { "total": 12, "limit": 50, "offset": 0 }
}
```

Errors: `401` no auth, `403` not admin, `503 users_unavailable` nếu V17 chưa wired.

### DELETE /v1/admin/users/:id

Response 204 No Content. Side effects:

1. Anonymise: `email = "deleted_<id>@deleted.local"`, `display_name = "(deleted)"`, `avatar_asset_id = ""`, `push_token = ""`, `push_token_platform = ""`
2. Set `deleted_at = now()`
3. Revoke all auth_tokens (session + verify + reset)
4. Email gốc được giải phóng cho re-registration (unique index `WHERE deleted_at IS NULL`)

Errors:
- `400 self_delete_forbidden` — `caller.ID == target.ID`
- `403 admin_delete_forbidden` — `target.Role == "admin"`
- `404` — user không tồn tại hoặc đã soft-deleted
- `401`/`403` — auth gate

### POST /v1/admin/users/:id/reset-password

Request body (max 4 KiB):
```json
{ "new_password": "BrandNew123!" }
```

Strength validation reuse `auth.ValidatePassword`:
- Min 8 ký tự
- Có ít nhất 1 chữ số hoặc ký tự đặc biệt
- Không có trong common-password block list

Response 204 No Content. Side effects:

1. `users.password_hash` cập nhật (bcrypt cost 12)
2. Revoke tất cả session token của user → mọi thiết bị bị logout
3. Reset login rate limiter cho `target.Email` → user có thể login ngay với mật khẩu mới

Errors:
- `400 invalid_body` / `400 weak_password` / `400 weak_password_common`
- `403 admin_reset_forbidden` — `target.Role == "admin"`
- `404` — user không tồn tại
- `401`/`403` — auth gate

**Note:** Admin không thể tự reset mật khẩu của chính mình qua endpoint này (admin role guard). Admin dùng flow self-serve `/v1/auth/forgot-password` hoặc operator update DB trực tiếp.

## CMS UI

Route `/users` (`cms/components/users-dashboard.tsx`):

```
┌─────────────────────────────────────────┐
│ QUẢN LÝ                       [Làm mới] │
│ Tài khoản                               │
│                                         │
│ [search input ………………] [Tìm] [Xóa lọc]   │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Email │ Tên │ Vai trò │ Pro │ ✓ │ … │ │
│ ├─────────────────────────────────────┤ │
│ │ ...   │ ... │ learner │ free│   │…  │ │
│ │                       [Đặt MK][Xóa] │ │
│ └─────────────────────────────────────┘ │
│ 1–50 / 124         [← Trước] [Sau →]    │
└─────────────────────────────────────────┘
```

- Admin row hiển thị `—` thay vì 2 nút action
- Click "Đặt lại MK" → modal với 2 input password + confirm + strength hint
- Click "Xóa" → confirm modal, sau khi xóa step về page trước nếu là item cuối
- Search submit reset offset = 0
- Sidebar nav: thêm "Tài khoản" / "Accounts" key `users` (i18n VI/EN)

## Files Touched

**Backend:**
- `internal/store/user_store.go` — interface + memory `ListUsers`
- `internal/store/postgres_users.go` — postgres `ListUsers` (LIKE search + COUNT total)
- `internal/httpapi/admin_users.go` — handlers (mới)
- `internal/httpapi/server.go` — route registration
- `internal/httpapi/admin_users_test.go` — 12 test (mới)

**CMS:**
- `app/api/admin/users/route.ts` — GET proxy
- `app/api/admin/users/[userId]/route.ts` — DELETE proxy
- `app/api/admin/users/[userId]/reset-password/route.ts` — POST proxy
- `components/users-dashboard.tsx` — page (mới)
- `components/cms-sidebar.tsx` — nav entry
- `lib/i18n.tsx` — VI `Tài khoản` / EN `Accounts`
- `app/users/page.tsx` — route entry

## Test Coverage

12 backend test trong `admin_users_test.go`:

- `TestAdminListUsers_RequiresAuth` — 401 no token
- `TestAdminListUsers_ReturnsActiveUsers` — happy path 2 users
- `TestAdminListUsers_SearchFiltersByEmail` — search filter
- `TestAdminDeleteUser_HappyPath_SoftDeletesAndRevokesTokens` — delete + revoke + email freed
- `TestAdminDeleteUser_NotFound_Returns404`
- `TestAdminDeleteUser_AdminRole_Forbidden` — 403
- `TestAdminDeleteUser_RequiresAdmin` — 401
- `TestAdminResetPassword_HappyPath_UpdatesHashAndRevokesSessions` — verify hash + token revoke
- `TestAdminResetPassword_WeakPassword_Returns400`
- `TestAdminResetPassword_NotFound_Returns404`
- `TestAdminResetPassword_AdminTarget_Forbidden`
- `TestAdminResetPassword_RequiresAdmin`

Full suite: 447/447 backend pass, 95/95 CMS Vitest pass.

## Operational Notes

- Nếu admin đặt lại password rồi muốn báo cho học viên: dùng kênh tin cậy (Telegram/Zalo/SMS), không bao giờ qua email vì có thể chính email đã bị compromise.
- Sau soft-delete, CMS `/learners` analytics dashboard vẫn hiển thị attempts của user_id đó (audit trail) — đây là chủ ý.
- V18 có thể thêm cron hard-delete sau N ngày + xoá luôn attempts cho compliance.
