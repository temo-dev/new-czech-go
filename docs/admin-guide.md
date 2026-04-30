# Admin Content Entry Guide

CMS URL: `http://localhost:3000` (local) hoặc `https://cmscz.hadoo.eu` (production)

---

## Thứ tự nhập liệu bắt buộc

```
1. Course
2. Module  (thuộc Course)
3. Skill   (thuộc Module, skill_kind = noi)
4. Exercise (thuộc Skill, pool = course, status = published)
```

MockTest độc lập — cần exercises riêng với `pool = exam`.

---

## 1. Tạo Course

**Trang:** `/courses` → nút **"Khóa học mới"**

| Field | Gợi ý |
|---|---|
| Tiêu đề | `Ôn thi A2 — trvalý pobyt` |
| Mô tả | `Lộ trình 8 tuần luyện nói cho kỳ thi xin thẻ thường trú` |
| Thứ tự | `1` |
| Trạng thái | `Đã xuất bản` |

---

## 2. Tạo Module

**Trang:** `/modules` → chọn Course → **"+ Module"**

Mỗi module là một tuần học hoặc chủ đề:

| Field | Gợi ý |
|---|---|
| Tiêu đề | `Tuần 1 · Giới thiệu bản thân` |
| Mô tả | `Chủ đề giới thiệu, gia đình, công việc` |
| Thứ tự | `1, 2, 3, ...` |
| Trạng thái | `published` |

---

## 3. Tạo Skill

**Trang:** `/skills` → chọn Module → **"+ Skill"**

Mỗi module nên có ít nhất 1 skill `noi`:

| Field | Gợi ý |
|---|---|
| Skill kind | `noi` |
| Title | `Nói — Tuần 1` |

> Các skill `nghe`, `doc`, `viet`, `tu_vung`, `ngu_phap` có thể tạo nhưng chưa có bài tập.

---

## 4. Tạo Exercise (quan trọng nhất)

**Trang:** `/` → form bên trái

### Tab "Đề bài"

**Task type — chọn loại bài:**

| Loại | Mô tả |
|---|---|
| `Úloha 1` | Trả lời 3-4 câu hỏi ngắn theo chủ đề |
| `Úloha 2` | Hội thoại — hỏi để lấy thông tin còn thiếu |
| `Úloha 3` | Kể chuyện theo 4 tranh |
| `Úloha 4` | Chọn 1 trong 3 phương án và giải thích lý do |

Điền các fields theo loại bài:
- **Úloha 1**: Title + 3-4 câu hỏi (mỗi câu 1 dòng)
- **Úloha 2**: Scenario title + Scenario prompt + Required info slots (format: `slot_key | label | sample question`)
- **Úloha 3**: Story title + Narrative checkpoints (mỗi checkpoint 1 dòng)
- **Úloha 4**: Scenario prompt + Choice options (format: `option_key | label | description`)

### Tab "Bài mẫu" (tùy chọn)

Điền câu trả lời mẫu tiếng Czech — sẽ hiện trong review sau khi học viên nộp bài.

### Tab "Metadata" — **BẮT BUỘC**

| Field | Giá trị |
|---|---|
| Pool | `Bài luyện khóa học (course)` |
| Module | Chọn module vừa tạo |
| Skill | Chọn skill `noi` |
| Status | **`published`** ← bắt buộc để Flutter thấy |

> **Lưu ý:** Exercise `status = draft` sẽ **không** hiện trên Flutter app.

---

## 5. Tạo Mock Test

**Trang:** `/mock-tests` → **"Mock mới"**

### Chọn loại kỳ thi — **Thi thật** hay **Luyện thi**

Đây là quyết định đầu tiên cần chọn:

| | **Thi thật** (`real`) | **Luyện thi** (`practice`) |
|---|---|---|
| Mục đích | Mô phỏng đúng format kỳ thi A2 NPI ČR | Luyện tập linh hoạt, sprint theo chủ đề |
| Sections | Admin tự chọn exercises phù hợp | Admin tự chọn bất kỳ skill nào |
| Ngưỡng đạt | Cố định theo spec NPI (≥24/40 nói, ≥42/70 viết) | Admin tự đặt (ví dụ: 70%, 80%) |
| Thời gian | Theo format thật | Linh hoạt |

> **Mặc định:** Nếu không chọn → hệ thống xử lý như "Luyện thi".

---

### Bước 1: Tạo exercises dùng cho thi (pool = exam)

Tạo ở trang `/` như trên, nhưng trong Tab "Metadata":
- Pool: **`Bài thi mock exam (exam)`**
- Không cần chọn module/skill

Số lượng exercises cần tạo phụ thuộc vào loại mock test:
- **Thi thật 4 kỹ năng:** cần exercises cho nói (Úloha 1-4), nghe (Poslech 1-5), đọc (Čtení 1-5), viết (Psaní 1-2)
- **Luyện thi sprint nói:** chỉ cần 4 exercises Úloha 1-4

### Bước 2: Tạo Mock Test

| Field | Gợi ý |
|---|---|
| Tiêu đề | `Mock Test 01 — Bản thân & nhà ở` |
| Mô tả | `Đề thi thử A2 toàn phần, 4 úloha` |
| Thời gian | `12` phút |
| **Loại kỳ thi** | `Luyện thi` hoặc `Thi thật` ← **chọn ở đây** |
| **Ngưỡng đạt %** | `80` (luyện thi) hoặc `60` (thi thật standard) |
| Status | `published` |

### Bước 3: Gán exercises vào sections

#### Ví dụ — Sprint nói (Luyện thi, 4 sections)

- Section 1 → exercise Úloha 1 (max 8 điểm)
- Section 2 → exercise Úloha 2 (max 12 điểm)
- Section 3 → exercise Úloha 3 (max 10 điểm)
- Section 4 → exercise Úloha 4 (max 7 điểm)

#### Ví dụ — Thi thật toàn phần (Thi thật, nhiều sections)

- Section 1 → Úloha 1 (max 8đ)
- Section 2 → Úloha 2 (max 12đ)
- Section 3 → Úloha 3 (max 10đ)
- Section 4 → Úloha 4 (max 7đ)
- Section 5 → Poslech 1 (max 5đ)
- Section 6 → Poslech 2 (max 5đ)
- ... (thêm các section nghe/đọc/viết)

> **Lưu ý:** Flutter app tự động route đúng màn hình theo exercise type. Không cần config thêm — `uloha_*` → màn hình nói, `poslech_*` → màn hình nghe, `cteni_*` → màn hình đọc, `psani_*` → màn hình viết.

---

## Kiểm tra sau khi nhập liệu

1. Mở Flutter app (iOS Simulator hoặc device)
2. Home → tap vào Course → Module → Skill
3. Danh sách bài tập hiện → tap → màn hình ghi âm mở
4. Ghi âm → Phân tích → Kết quả với feedback AI

Nếu không thấy bài tập: kiểm tra exercise `status = published` và đúng `pool = course`.

---

## Xóa & reset

Xóa toàn bộ data (giữ schema):
```sql
-- Chạy trong psql hoặc docker compose exec postgres psql -U postgres -d czech_go_system
TRUNCATE TABLE attempt_review_artifacts, attempt_feedback, attempt_audio,
  attempt_transcripts, attempts, mock_exam_sections, mock_exam_sessions,
  mock_test_sections, mock_tests, exercises,
  skills, modules, courses CASCADE;
```

> **Lưu ý V9:** Bảng `full_exam_sessions` đã được xóa — không còn tồn tại trong schema.
