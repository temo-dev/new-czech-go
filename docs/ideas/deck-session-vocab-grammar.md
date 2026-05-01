# Deck Session Mode cho Từ vựng & Ngữ pháp

## Problem Statement
HMW biến danh sách bài tập rời rạc thành session học liên tục theo loại bài — học xong một loại mới chuyển, không phải tap từng card một.

## Recommended Direction

**Type Group → Type List → Deck Session** — 3-level flow:

1. **Type Group Screen** (thay thế list hiện tại cho skill tu_vung/ngu_phap): 4 card lớn — Flashcard / Ghép đôi / Điền từ / Chọn từ — mỗi card hiển thị badge số lượng published exercises
2. **Type List Screen**: list exercises của type đó + nút **"Bắt đầu học tất cả (N)"** ở top. Individual tap vẫn hoạt động như cũ
3. **Deck Session Screen**: queue controller sequential
   - Progress bar + counter "3/8"
   - Anki loop: "Ôn lại" → đẩy card về cuối queue; "Đã biết" → bỏ khỏi queue
   - Khi queue rỗng → Completion screen (X/N đã biết, nút "Ôn lại X từ nữa" hoặc "Xong")
   - **Local scoring only** — không gọi attempt API, check đúng/sai trên device

## Key Assumptions to Validate
- [ ] Local scoring đủ cho quizcard/matching/fill_blank/choice_word (không cần lưu backend)
- [ ] User không cần xem lịch sử "đã học hôm nay bao nhiêu từ" — nếu cần thì phải gọi API
- [ ] 4 type groups đủ, không cần nhóm thêm theo module trong type group screen

## MVP Scope

**Trong:**
- `TypeGroupScreen` — 4 group cards thay thế exercise list khi vào tu_vung/ngu_phap
- `TypeListScreen` — list exercises filter theo type + "Bắt đầu học tất cả" button
- `DeckSessionScreen` — queue controller, Anki loop, local answer check, completion screen
- Render inline per-type trong DeckSession (không reuse VocabGrammarExerciseScreen)

**Ngoài:**
- Spaced repetition thuật toán (SM-2)
- Server-side progress tracking cho deck sessions
- Cross-session "hôm nay học bao nhiêu từ"
- Audio per card trong deck mode

## Not Doing (và Why)
- **Gọi attempt API mỗi card trong deck** — quá nặng, làm chậm UX, offline không học được
- **SM-2 spaced repetition** — over-engineering cho V1; app focus là luyện thi, không phải SRS dài hạn
- **Auto-advance sang type tiếp theo** — completion screen cho user tự quyết, ít giả định hơn

## Open Questions
- Module selector trong Type Group Screen hay lấy theo module đang active?
- Completion screen có nút "Làm bài test" (jump sang MockExam) không?
