# Admin User Management (V17.1)

## Problem Statement

Sau khi V17 self-serve auth lên production, admin cần công cụ trong CMS để:
1. Thấy danh sách tài khoản học viên đã đăng ký (email, tên, role, pro tier, verified)
2. Xoá tài khoản khi học viên yêu cầu hoặc tài khoản spam
3. Đặt lại mật khẩu giúp học viên khi họ mất quyền truy cập email và không tự reset được

V17 ban đầu chỉ ship endpoint `GET /v1/admin/users` (read-only) và defer CRUD sang V18. Thực tế operations cần delete + reset-password ngay vì học viên test đầu tiên đã gặp tình huống này.

## Recommended Direction

Mở rộng V17 với 3 admin endpoint nhỏ — không tạo bảng mới, không thay đổi luồng learner. Tất cả thao tác là soft-mutate trên `users` table và revoke session tokens; không có hard delete.

| Endpoint | Method | Tác dụng |
|---|---|---|
| `/v1/admin/users` | GET | List paginated, optional `search` + `role` filter |
| `/v1/admin/users/:id` | DELETE | Soft-delete: anonymise email/name/avatar/push_token, set `deleted_at`, revoke all auth tokens, free email cho re-register |
| `/v1/admin/users/:id/reset-password` | POST | Admin set password mới trực tiếp (validate strength, bcrypt hash, revoke all sessions, reset login rate limit) |

CMS UI: route mới `/users` với table + search + paginate + 2 nút "Đặt lại MK" / "Xóa" mỗi row + confirm modal.

## Key Assumptions to Validate

- [x] `userStore.ListUsers` thêm vào interface không phá vỡ V17 store wiring (Postgres + memory)
- [x] `withRole("admin")` đủ guard cho tất cả endpoint (không cần guard riêng)
- [x] Admin role target từ chối cả delete + reset-password (footgun guard)
- [x] Self-delete refuse khi `caller.ID == target.ID`

## MVP Scope

**In:**
- 3 endpoint backend trên cùng router `handleAdminUserByID` (sub-path dispatch)
- CMS `/users` page + sidebar nav entry "Tài khoản"
- Reset-password: admin tự gõ mật khẩu mới trong modal CMS, gửi cho học viên qua kênh an toàn (chat/sms), không qua email reset link
- Soft-delete giữ nguyên `attempts.user_id` để audit trail không bị dangling

**Out:**
- Admin tạo learner mới (vẫn chỉ self-serve signup)
- Admin chỉnh sửa email/display_name/role
- Bulk delete / export CSV
- Admin trigger password-reset email (đã có flow self-serve)
- Hard delete (V18+ nếu cần GDPR right-to-erasure cron)

## Security

- `withRole("admin")` middleware (legacy `dev-admin-token` + V17 admin session token)
- Admin role target → 403 (admins rotate creds out-of-band)
- Self-delete → 400
- Reset password reuse `auth.ValidatePassword` (cùng common-password block list, min 8, alpha+symbol)
- Body cap 4 KiB qua `http.MaxBytesReader`
- Response 204 No Content không leak gì thêm

## Non-Goals

- Không log mật khẩu mới (admin nhập + nhớ rồi gửi cho học viên)
- Không tự động email mật khẩu mới — kênh email coi là untrusted
