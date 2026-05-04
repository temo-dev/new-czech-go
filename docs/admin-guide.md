# Admin Content Entry Guide

CMS URL: `http://localhost:3000` (local) hoặc `https://cmscz.hadoo.eu` (production)

---

## Thứ tự nhập liệu bắt buộc

```
1. Course
2. Module  (thuộc Course)
3. Exercise (thuộc Module trực tiếp, pool = course, status = published)
```

MockTest độc lập — cần exercises riêng với `pool = exam`.

> **V8:** Bảng `skills` đã được xóa. Exercise link thẳng vào Module qua `module_id`. `skill_kind` (noi/nghe/doc/viet/tu_vung/ngu_phap) được lưu trực tiếp trên exercise.

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

## 3. Tạo Exercise (quan trọng nhất)

**Trang:** `/` → Tab **"Khoá học"**

### Coverage Matrix — xem nhanh tình trạng nội dung

Trang exercise hiển thị bảng **Module × Kỹ năng** (Nói / Nghe / Viết / Đọc):

| Màu ô | Ý nghĩa |
|-------|---------|
| 🔴 Đỏ (0–5) | Thiếu nghiêm trọng |
| 🟡 Vàng (6–14) | Còn thiếu |
| 🟢 Xanh nhạt (15–19) | Gần đủ |
| 🟢 Xanh đậm (≥20) | Đủ (target = 20 published) |

Số nhỏ bên dưới = số bản nháp chưa xuất bản.

**Cách dùng nhanh:**
1. Nhìn vào matrix → tìm ô đỏ/vàng
2. Click ô đó → list bên dưới tự filter theo module + kỹ năng
3. Click **"+ Tạo exercise"** → form tự điền sẵn Module và Skill Kind từ ô đang chọn

### Wizard tạo exercise mới

Khi click "+ Tạo exercise":

**Bước 1 — Chọn kỹ năng** (bỏ qua nếu click từ matrix cell):
Nói / Viết / Nghe / Đọc / Từ vựng / Ngữ pháp

**Bước 2 — Chọn dạng bài:**

| Loại | Mô tả |
|---|---|
| `Úloha 1` | Trả lời 3-4 câu hỏi ngắn theo chủ đề |
| `Úloha 2` | Hội thoại — hỏi để lấy thông tin còn thiếu |
| `Úloha 3` | Kể chuyện theo 4 tranh |
| `Úloha 4` | Chọn 1 trong 3 phương án và giải thích lý do |
| `Psaní 1` | Điền form (3 câu hỏi, ≥10 từ/câu) |
| `Psaní 2` | Viết email theo 5 ảnh gợi ý (≥35 từ) |
| `Poslech 1–5` | Các dạng nghe khác nhau |
| `Čtení 1–5` | Các dạng đọc khác nhau |
| `Phỏng vấn hội thoại` | Hội thoại thực tế với avatar AI examiner (V14) |
| `Phỏng vấn chọn phương án` | Chọn 1 phương án rồi giải thích với examiner AI (V14) |

**Bước 3 — Nhập nội dung:**

Điền các fields theo loại bài:
- **Úloha 1**: Title + 3-4 câu hỏi (mỗi câu 1 dòng)
- **Úloha 2**: Scenario title + Scenario prompt + Required info slots (format: `slot_key | label | sample question`)
- **Úloha 3**: Story title + Narrative checkpoints (mỗi checkpoint 1 dòng)
- **Úloha 4**: Scenario prompt + Choice options (format: `option_key | label | description`)

**Mục "Bài mẫu"** (tùy chọn): Điền câu trả lời mẫu tiếng Czech.

**Mục "Cài đặt xuất bản"** — **BẮT BUỘC kiểm tra:**

| Field | Giá trị |
|---|---|
| Pool | `Bài luyện khóa học (course)` |
| Module | Chọn module vừa tạo (tự điền nếu click từ matrix) |
| Skill Kind | Để trống → backend tự derive. Chỉ cần chọn cho `matching`/`fill_blank`/`choice_word` (phân biệt `tu_vung` / `ngu_phap`) |
| Status | **`published`** ← bắt buộc để Flutter thấy |

> **Lưu ý:** Exercise `status = draft` sẽ **không** hiện trên Flutter app. Matrix chỉ đếm exercises `published` vào màu sắc.

### Autosave

Form tự lưu nháp vào localStorage mỗi 10 giây. Nếu thoát nhầm, lần sau mở form sẽ hỏi "Khôi phục bản nháp?".

---

---

## 4. Tạo bài Phỏng vấn AI (V14)

Skill kind: `interview`. Learner hội thoại real-time với avatar Czech examiner dùng ElevenLabs Conversational AI.

> **Yêu cầu:** Backend phải có `ELEVENLABS_API_KEY` trong `.env`.

### 4a. Phỏng vấn theo chủ đề (`interview_conversation`)

**Trang:** `/` → "+ Tạo exercise" → Bước 1: chọn **"Phỏng vấn AI"** → Bước 2: **"Hội thoại theo chủ đề"**

| Field | Gợi ý | Bắt buộc |
|---|---|---|
| Tiêu đề | `Gia đình và bạn bè` | ✓ |
| Chủ đề | `Gia đình, anh chị em, sở thích` | ✓ |
| System Prompt | Xem mẫu bên dưới | ✓ |
| Max turns | `6` – `8` | |
| Hiển thị transcript | Bật để learner thấy phụ đề | |
| Gợi ý cho learner | Tối đa 5 tips hiển thị ở Intro screen | |

**System Prompt mẫu:**
```
You are Jana Nováková, a friendly Czech language examiner for the A2 certification exam.
Conduct a conversational interview in Czech about family and friends.
Ask 5-7 natural questions appropriate for A2 level learners.
Start with "Dobrý den!" and introduce yourself briefly.
If the learner makes errors, continue naturally without correcting.
Respond only in Czech.
```

> **Lưu ý:** System prompt quyết định hoàn toàn cách avatar AI hành xử. Viết rõ ngôn ngữ, chủ đề, phong cách hỏi và giới hạn level.

### 4b. Phỏng vấn chọn phương án (`interview_choice_explain`)

**Trang:** "/` → "+ Tạo exercise" → Bước 2: **"Chọn phương án + giải thích"**

| Field | Gợi ý | Bắt buộc |
|---|---|---|
| Tiêu đề | `Chọn địa điểm du lịch` | ✓ |
| Câu hỏi chính | `Bạn muốn đi du lịch ở đâu?` | ✓ |
| Các phương án | 1–4 options (tên + ảnh tùy chọn) | ✓ (1 min) |
| Gợi ý theo phương án | Mỗi option có tối đa 5 gợi ý, chỉ hiện sau khi learner chọn phương án đó | |
| System Prompt | Phải chứa `{selected_option}` | ✓ |
| Max turns | `5` – `6` | |

**System Prompt mẫu:**
```
You are Jana Nováková, a Czech A2 examiner.
The learner has chosen {selected_option} as their preferred travel destination.
Acknowledge their choice in Czech, then ask 4-5 follow-up questions:
why they chose it, what they would do there, who they would travel with, etc.
Keep the conversation natural and at A2 level.
```

> **Quan trọng:** `{selected_option}` bắt buộc có trong System Prompt — backend inject lựa chọn thực tế của learner vào đây trước khi gọi ElevenLabs.

### Kiểm tra bài phỏng vấn

1. App → Module → **"Phỏng vấn AI"**
2. Chọn bài → Intro screen hiện (topic / options)
3. Nhấn "Bắt đầu" → màn hình tối, avatar hiện
4. Nói tiếng Czech → avatar trả lời
5. Nhấn "Kết thúc" → xác nhận → chờ chấm điểm → xem kết quả

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
- Không cần chọn module (pool=exam exercises không thuộc module)

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
