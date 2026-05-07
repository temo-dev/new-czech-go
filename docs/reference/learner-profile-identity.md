# Learner Profile Identity Spec (V17.2)

**Status:** ✅ Implemented 2026-05-05
**Depends on:** V17 self-serve auth, V11 media-enrichment (`uploadItemImage` helper)
**Idea:** [`docs/ideas/learner-profile-identity.md`](../ideas/learner-profile-identity.md)

## Goal

Học viên đăng nhập có thể tự đặt biệt danh + ảnh đại diện trong app, không cần admin can thiệp. ProfileScreen hiển thị đúng identity từ AuthService thay vì placeholder hardcode.

## Non-Goals

- Avatar crop / filter / multi-photo timeline
- Avatar trong leaderboard / attempt list
- Custom theme / cover photo
- Server-side image moderation

## Architecture

```
Flutter ProfileScreen
   │
   ├── V17AccountSection (hero)
   │     │
   │     ├── _AvatarTile (96pt circle, tap → action sheet)
   │     │     │
   │     │     ├── ImagePicker (camera/gallery)
   │     │     ├── ApiClient.uploadAvatarV17(File)  ─→ POST /v1/users/me/avatar
   │     │     ├── ApiClient.deleteAvatarV17()      ─→ DELETE /v1/users/me/avatar
   │     │     └── AuthService.refresh()            ─→ GET /v1/users/me
   │     │
   │     └── _EditNicknameButton (pencil icon → dialog)
   │           │
   │           ├── patchMeV17({"display_name": ...}) ─→ PATCH /v1/users/me
   │           └── AuthService.refresh()
   │
   └── Image.network(mediaUri(asset_id))            ─→ GET /v1/media/file?key=avatars/<user_id>/<id>.<ext>
```

`uploadItemImage` helper (V11) là điểm reuse: cùng MIME whitelist, 5 MB cap, storage key sinh tự động.

## Data Model

Không thêm bảng / cột mới. Reuse:

| Bảng | Cột | Hành động |
|---|---|---|
| `users` | `display_name` | Mutate qua `UpdateUser`; cap 60 runes phía API |
| `users` | `avatar_asset_id` | Mutate qua `UpdateUser`; trả storage key (e.g. `avatars/u_abc/img-...png`) |
| Filesystem | `<LOCAL_ASSETS_DIR>/avatars/<user_id>/img-<nanos>.<ext>` | Tạo qua `os.MkdirAll` + `os.Create`; xoá khi upload mới hoặc delete |

`patchMeRequest` thêm field:
```go
type patchMeRequest struct {
    DisplayName       *string `json:"display_name,omitempty"`
    AvatarAssetID     *string `json:"avatar_asset_id,omitempty"` // NEW
    // ...existing fields
}
```

`display_name` validation thêm 60-rune cap (qua `utf8.RuneCountInString` để đếm ký tự tiếng Việt đúng).

## Endpoints

### POST /v1/users/me/avatar

Upload ảnh đại diện. Request body: multipart/form-data với field `file`.

**Auth:** Bearer V17 session token.

**Limits:**
- Max body 5 MB (1 KiB extra cho boundary)
- MIME whitelist: `image/jpeg`, `image/png`, `image/webp`

**Response 200:**
```json
{
  "data": {
    "image_asset_id": "avatars/u_e330f213007ba960/img-1714912088123456789.png",
    "mime_type": "image/png"
  },
  "meta": {}
}
```

**Side effects:**
1. Lưu file vào `<LOCAL_ASSETS_DIR>/avatars/<user_id>/img-<nanos>.<ext>`
2. `users.avatar_asset_id` cập nhật qua `UpdateUser` mutator
3. Old avatar file xoá trên disk (nếu có)

**Errors:**
- `413 payload_too_large` — > 5 MB
- `415 unsupported_media_type` — MIME không trong whitelist
- `400 validation_error` — multipart parse fail
- `401` — không có Bearer token

### DELETE /v1/users/me/avatar

Xoá avatar hiện tại.

**Auth:** Bearer V17 session token.

**Response:** `204 No Content`

**Side effects:**
1. `users.avatar_asset_id = ""`
2. File trên disk bị xoá

### PATCH /v1/users/me (extended)

Đổi `display_name` (optional) hoặc `avatar_asset_id` (optional, hiếm khi học viên trực tiếp set — UI dùng upload endpoint trên).

**Request:**
```json
{ "display_name": "depzai3" }
```

**Validation:**
- `display_name` ≤ 60 runes (UTF-8 aware)

**Errors:**
- `400 display_name_too_long` — > 60 runes

## Flutter UI

### ProfileScreen layout (V17 mode)

```
┌────────────────────────────────────────┐
│ ListView                               │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │     ╭─────────────╮              │  │
│  │     │  [Avatar]   │  ← 96pt circle, camera badge bottom-right
│  │     │    96pt     │     tap → action sheet
│  │     ╰─────────────╯              │  │
│  │                                  │  │
│  │      depzai3  ✏️                  │  ← 22pt bold + edit pencil
│  │   anh.ngt18@gmail.com            │  ← 14pt secondary
│  │                                  │  │
│  │     [Free]  [✓ Đã xác minh]      │  ← chip pills wrap
│  │                                  │  │
│  │  ⚠️ Email chưa xác minh banner   │  ← only when !emailVerified
│  └──────────────────────────────────┘  │
│                                        │
│  🔒 Đổi mật khẩu                  →   │  ← action tiles
│  @  Đổi email                     →   │
│  →  Đăng xuất                     →   │
│  🗑  Xoá tài khoản (đỏ)            →   │
│                                        │
│  ── NGÔN NGỮ ──                       │
│  ...                                   │
└────────────────────────────────────────┘
```

### `_AvatarTile` Stack layering

```
Stack(fit: StackFit.expand)
  ├─ DecoratedBox (circle bg, alpha 0.12 primary)        ← visible behind initials
  ├─ if avatarUrl == null
  │     └─ Center(Text(initials))                         ← e.g. "DZ"
  │  else
  │     └─ ClipOval(Image.network(width: size, height: size, fit: cover))
  │                                                        ← fills circle, crops outside
  ├─ Positioned(bottom-right, camera badge)              ← visual affordance
  └─ if _busy → ClipOval(Container(black 0.35) + spinner)
```

**Bug fix:** Trước đây `Container(alignment: center, child: ClipOval(Image.network))` shrink ảnh về intrinsic size → ảnh nhỏ giữa background. Sau redesign Stack expand + Image.network ràng buộc width/height → ảnh fill khít circle.

### Action sheet (bottom sheet)

Tap avatar → modal bottom sheet:
- Chụp ảnh (`ImageSource.camera`)
- Chọn từ thư viện (`ImageSource.gallery`)
- Xoá ảnh đại diện (chỉ hiện khi `avatar_asset_id` không rỗng) — màu error
- Huỷ

`ImagePicker.pickImage(maxWidth: 1024, maxHeight: 1024, imageQuality: 85)` resize phía client → giảm bandwidth + size.

### Edit nickname dialog

`AlertDialog` với `TextField(maxLength: 60)` + autofocus + Lưu/Huỷ. Gọi `patchMeV17({'display_name': trimmed})` → `service.refresh()`.

### `AuthService._adoptUser` fix

```dart
void _adoptUser(AuthUser user) {
  _user = user;
  final next = (!user.emailVerified && user.graceAttemptsLeft <= 0)
      ? AuthState.needsVerify
      : AuthState.authenticated;
  if (_state == next) {
    notifyListeners();          // user fields changed but state unchanged
  } else {
    _setState(next);            // also notifies
  }
}
```

Trước fix: `_setState` no-op khi state không đổi → `AnimatedBuilder` không rebuild → UI cũ. Sau fix: luôn notify khi `_user` mutate.

## Files Touched

**Backend:**
- `internal/httpapi/auth_handlers.go` — `patchMeRequest` thêm `avatar_asset_id`; `display_name` 60-rune cap; route registration
- `internal/httpapi/user_avatar.go` — `handleUsersMeAvatar` POST/DELETE (mới)
- `internal/httpapi/user_avatar_test.go` — 5 test (mới)

**Flutter:**
- `pubspec.yaml` — `image_picker: ^1.1.2`, `http: ^1.2.2`
- `lib/core/api/api_client.dart` — `uploadAvatarV17(File)` + `deleteAvatarV17` + `_guessImageMime` helper
- `lib/core/auth/auth_service.dart` — `_adoptUser` luôn notify
- `lib/features/profile/screens/profile_screen.dart` — bỏ `_Avatar` legacy, V17 hero promote lên top
- `lib/features/profile/widgets/v17_account_section.dart` — `_AvatarTile` Stack restructure (fit avatar đúng circle), `_VerifiedChip` mới, hero centered layout với avatar 96pt + initials fallback từ display_name/email
- `ios/Runner/Info.plist` — `NSPhotoLibraryUsageDescription`

## Test Coverage

5 backend test trong `user_avatar_test.go`:
- `TestAvatar_Upload_HappyPath` — upload PNG + verify storage key + me reflects
- `TestAvatar_Upload_WrongMime_Returns415` — PDF reject
- `TestAvatar_Upload_RequiresAuth` — 401
- `TestAvatar_Delete_ClearsAssetId` — DELETE 204 + me empty
- `TestPatchMe_UpdatesDisplayName_TooLongRejected` — 61-char display_name → 400

Full suite: 452 backend, 201 Flutter, 95 CMS Vitest.

## Operational Notes

- `LOCAL_ASSETS_DIR` cần persist (named volume `backend_assets` đã có sẵn) — restart container không mất avatar
- Production: nếu cần CDN cho avatar, refactor sang S3 sau (giống pattern attempt audio); hiện tại local-disk đủ vì avatar size nhỏ + low traffic
- Cron orphan cleanup: V18+ có thể quét `avatars/` xoá file không có `users.avatar_asset_id` reference (sau soft-delete user qua `serveDeleteMe`)
- Avatar không tự xoá khi soft-delete account (`serveDeleteMe` clear `avatar_asset_id` trên DB nhưng file vẫn còn) — defer cleanup cho V18
