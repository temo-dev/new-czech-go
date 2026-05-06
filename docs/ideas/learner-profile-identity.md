# Learner Profile Identity (V17.2)

## Problem Statement

Sau khi V17 self-serve auth chạy production, học viên không có cách nào set biệt danh hoặc ảnh đại diện cá nhân. Profile screen hiển thị placeholder hardcode "Học viên" + "learner@example.com" — sai data, gây lẫn lộn với tên thật ("depzai3", email Gmail) ở card V17 bên dưới.

3 vấn đề cụ thể:
1. Backend không expose endpoint upload avatar; `users.avatar_asset_id` đã có cột nhưng chưa wired vào PATCH `/v1/users/me`
2. Flutter chưa có UI để học viên đổi biệt danh + upload ảnh
3. ProfileScreen có 2 layer hiển thị learner identity (legacy hero + V17 card) → duplicate, một sai một đúng

## Recommended Direction

Thêm tính năng identity self-service nhỏ gọn — không bảng mới, không asset CDN. Reuse existing `uploadItemImage` helper (avatars/ prefix) và serve qua `/v1/media/file?key=`.

| Component | Hành động |
|---|---|
| Backend `patchMeRequest` | Thêm `avatar_asset_id` (optional pointer) + `display_name` 60-char cap |
| Backend `/v1/users/me/avatar` | POST multipart (≤5 MB jpg/png/webp) + DELETE clear; reuse `uploadItemImage` |
| Flutter ApiClient | `uploadAvatarV17(File)` (manual multipart qua dart:io) + `deleteAvatarV17` |
| Flutter ProfileScreen | Bỏ `_Avatar` legacy hardcode, promote V17AccountSection thành hero centered (96pt avatar + name + edit pencil + email + Pro/verified chips) |
| Flutter AuthService | `_adoptUser` notify ngay cả khi state không đổi (display_name/avatar_asset_id mutate) |
| iOS Info.plist | `NSPhotoLibraryUsageDescription` (camera đã có từ V14 interview) |

## Key Assumptions to Validate

- [x] `uploadItemImage` đủ generic dùng cho avatars storagePrefix (đã reuse cho course banners, mock test banners trong V11) — confirmed working
- [x] image_picker tương thích iOS 13+ (deployment target hiện tại)
- [x] `Image.network` với `width`/`height` + `fit: BoxFit.cover` đủ ràng buộc kích thước trong `Stack(fit: expand)` để ảnh fill circle không bị shrink
- [x] AuthService notifyListeners khi user payload thay đổi nhưng state giữ nguyên — bug-fix, không chỉ enhancement

## MVP Scope

**In:**
- Avatar upload + delete + display
- Nickname (display_name) edit
- Hero header centered: avatar + name + edit + email + Pro chip + verified chip
- Email-verified banner khi chưa xác minh
- Camera badge overlay trên avatar (visual affordance cho tap)
- Action sheet bottom: chụp ảnh / chọn thư viện / xoá avatar / huỷ

**Out:**
- Avatar crop/zoom UI (image_picker tự resize 1024×1024 + quality 85)
- Multiple avatar history
- Avatar moderation / NSFW filter (defer)
- Custom themes / cover photo
- Show avatar trong attempt history hoặc leaderboard (defer)

## Security

- Avatar upload yêu cầu V17 session token (`requireV17User`)
- 5 MB cap qua `http.MaxBytesReader`
- Whitelist MIME: `image/jpeg`, `image/png`, `image/webp` — reject PDF/HTML/SVG
- Storage key `avatars/<user_id>/<asset_id>.<ext>` — `<user_id>` đảm bảo không collision giữa users
- `display_name` 60-char cap qua `utf8.RuneCountInString` (không phải `len()` để tránh bug ký tự multi-byte tiếng Việt)
- Old avatar file xóa trên disk khi upload mới hoặc delete — không tích lũy orphan

## Non-Goals

- Avatar không impact pricing / pro tier
- Không có avatar mặc định stock — fallback dùng initials từ `display_name` hoặc email local-part
