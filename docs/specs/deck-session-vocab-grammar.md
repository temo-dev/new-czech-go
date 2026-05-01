# Spec: Deck Session Mode — Từ vựng & Ngữ pháp (V12)

**Status:** Draft · 2026-05-01  
**Scope:** Flutter iOS only. No backend changes. No CMS changes.  
**Reference:** `docs/ideas/deck-session-vocab-grammar.md`, `docs/designs/deck-session-vocab-grammar.html`

---

## 1. Objective

Biến danh sách bài tập từ vựng/ngữ pháp rời rạc (tap từng card) thành một **deck session liên tục** theo loại bài. Người học có thể học hết flashcard rồi mới chuyển sang ghép đôi, thay vì phải tap từng bài một.

**Target user:** Học viên Việt Nam luyện Czech A2 trên iPhone.  
**Success metric:** Người học có thể hoàn thành toàn bộ flashcard trong một module mà không cần quay lại list giữa chừng.

---

## 2. User Flow

```
ModuleDetailScreen
  └─ tap skill "Từ vựng" (tu_vung) hoặc "Ngữ pháp" (ngu_phap)
       │
       ▼  [CHANGE] thay vì ExerciseListScreen → mở TypeGroupScreen
  TypeGroupScreen (NEW)
  ├─ tap type card (Flashcard / Ghép đôi / Điền từ / Chọn từ)
  │    ▼
  │  VocabTypeListScreen (NEW)
  │  ├─ "Bắt đầu học tất cả (N)" button  →  DeckSessionScreen (NEW)
  │  └─ tap individual exercise           →  VocabGrammarExerciseScreen (existing, unchanged)
  │
  └─ [unchanged] tap individual skill card vẫn mở ExerciseListScreen
       (chỉ thay đổi khi skillKind == tu_vung || ngu_phap)
```

### Deck Session Loop

```
DeckSessionScreen
  Queue: [E1, E2, E3, E4, E5]  (loaded from API, filtered by exerciseType)
  
  show current = queue.first
    ├─ quizcard_basic: tap card → flip → [Đã biết] / [Ôn lại]
    │    Đã biết → knownIds.add(id), queue.removeFirst(), next
    │    Ôn lại  → queue.removeFirst(), queue.addLast(current), next
    │
    ├─ choice_word:  tap option → local check → [Tiếp theo]
    ├─ fill_blank:   type → submit → local check → [Tiếp theo]
    └─ matching:     MatchingWidget → all correct → [Tiếp theo]
         (choice/fill/matching: always "correct" in deck = Đã biết behavior)
  
  queue.isEmpty → CompletionScreen
```

---

## 3. New Files

```
flutter_app/lib/features/exercise/screens/
  type_group_screen.dart          # TypeGroupScreen
  vocab_type_list_screen.dart     # VocabTypeListScreen
  deck_session_screen.dart        # DeckSessionScreen (+ CompletionView inline)
```

No new routes, no router changes — screens pushed imperatively via `Navigator.push` (same pattern as current codebase).

---

## 4. Screen Specifications

### 4.1 TypeGroupScreen

**Purpose:** Nhóm exercises theo loại bài, hiện badge số lượng.

**Constructor:**
```dart
TypeGroupScreen({
  required ApiClient client,
  required String moduleId,
  required String skillKind,   // 'tu_vung' | 'ngu_phap'
  required String moduleTitle, // for AppBar
})
```

**Data loading:**
- `GET /v1/modules/:moduleId/exercises?skill_kind=:skillKind` (đã có)
- Parse `ExerciseSummary` list, group by `exerciseType`
- 4 nhóm: `quizcard_basic`, `matching`, `fill_blank`, `choice_word`
- Chỉ hiện nhóm có `count > 0`

**UI:**
- AppBar: `moduleTitle` + skill label ("Từ vựng" / "Ngữ pháp")
- Body: 2×2 grid of type cards (xem design)
- Mỗi card: icon + label + count badge ("N bài") + chevron
- Tap card → `Navigator.push(VocabTypeListScreen(...))`

**Type card labels/icons:**

| exerciseType | Label | Icon (text) | Color |
|---|---|---|---|
| `quizcard_basic` | Flashcard | 📚 | `primaryContainer` |
| `matching` | Ghép đôi | ↔ | `secondaryContainer` |
| `fill_blank` | Điền từ | ✏ | `tertiaryContainer` |
| `choice_word` | Chọn từ | ✓ | `surfaceContainerHighest` |

**Empty state:** Nếu không có exercise nào → hiện message "Chưa có bài tập" (dùng `Text` giống các screen khác).

**Loading:** `CircularProgressIndicator` căn giữa trong khi fetch.

---

### 4.2 VocabTypeListScreen

**Purpose:** List exercises của một loại + "Bắt đầu học tất cả" button.

**Constructor:**
```dart
VocabTypeListScreen({
  required ApiClient client,
  required String moduleId,
  required String exerciseType,  // 'quizcard_basic' | 'matching' | ...
  required String typeLabel,     // 'Flashcard' | 'Ghép đôi' | ...
  required List<ExerciseSummary> exercises,  // pre-loaded từ TypeGroupScreen
})
```

**UI:**
- AppBar: `typeLabel` + count badge pill
- Top: `ElevatedButton` full-width — "▶ Bắt đầu học tất cả (N)" (primary color, box shadow)
  - Tap → `Navigator.push(DeckSessionScreen(...))`
- Divider label: "Hoặc học từng bài"
- ListView: `ExerciseSummary` list items (tái sử dụng style từ ExerciseListScreen)
  - Tap → `_openExercise()` → `VocabGrammarExerciseScreen` (same pattern as current code)

**Data:** Nhận `exercises` list từ parent (TypeGroupScreen) — không fetch lại. Exercises đã được filter theo `exerciseType`.

**Note:** `_openExercise` cần load full `ExerciseDetail` (same as ExerciseListScreen line 56–115).

---

### 4.3 DeckSessionScreen

**Purpose:** Sequential deck player với Anki-style queue.

**Constructor:**
```dart
DeckSessionScreen({
  required ApiClient client,
  required String moduleId,
  required String exerciseType,
  required String typeLabel,
  required List<ExerciseSummary> exercises,
})
```

**State:**
```dart
Queue<ExerciseSummary> _queue;   // ListQueue, mutable
Set<String> _knownIds;           // exercise ids marked "Đã biết"
int _totalCount;                 // exercises.length, fixed
ExerciseDetail? _currentDetail;  // loaded detail for queue.first
bool _loadingDetail;
bool _sessionComplete;           // true khi queue empty
```

**Initialization:**
- `_queue = ListQueue.from(exercises)` (giữ order từ API)
- `_totalCount = exercises.length`
- Load `ExerciseDetail` cho `queue.first` → async

**Progress:**
```dart
int get _doneCount => _knownIds.length + (_totalCount - _queue.length - (_knownIds.length));
// Đơn giản hơn:
int get _progressCount => _totalCount - _queue.length + _knownIds.length;
// hoặc: bài đã xử lý = totalCount - queue.length (kể cả "Ôn lại" đã xử lý 1 lần)
```

Thực tế cần track riêng:
```dart
int _processedCount = 0;  // tăng mỗi lần user chọn Đã biết hoặc Ôn lại
// progress = _processedCount / (_processedCount + _queue.length)
```

**Progress bar:** `LinearProgressIndicator(value: _processedCount / _totalCount)`  
Nhưng vì queue có thể lớn hơn totalCount (Ôn lại loop), hiển thị `"${_knownIds.length}/${_totalCount} đã biết"` thay số tuyệt đối.

**Thực tế progress UI:**
- Counter: `"${_knownIds.length} / $_totalCount đã biết"`
- Progress bar: `_knownIds.length / _totalCount` (0→1 khi tất cả known)

**Per-type rendering trong deck:**

#### `quizcard_basic`
- Render `QuizcardWidget` (existing widget, không thay đổi)
  - `front`: `detail.flashcardFront`
  - `back`: `detail.flashcardBack`
  - `example`: `detail.flashcardExample`
  - `submitting`: false (local only)
  - `onChoice`: `(choice) => _handleQuizcardChoice(choice)`
- Không cần submit button (QuizcardWidget tự có Đã biết/Ôn lại)

```dart
void _handleQuizcardChoice(String choice) {
  if (choice == 'known') {
    _knownIds.add(_queue.first.id);
    _queue.removeFirst();
  } else {
    final current = _queue.removeFirst();
    _queue.addLast(current);
  }
  _processedCount++;
  if (_queue.isEmpty) {
    setState(() => _sessionComplete = true);
  } else {
    _loadNextDetail();
  }
}
```

#### `choice_word`
- Hiện `detail.choiceWordStem` (sentence)
- 4 options từ `detail.multipleChoiceOptions`
- Tap option → local check: `tappedKey == detail.correctAnswers['1']`
  - Correct: highlight green
  - Wrong: highlight red + highlight correct green
- "Tiếp theo →" button → advance queue (always treated as "known" sau khi xem đáp án)

#### `fill_blank`
- Hiện `detail.fillBlankSentence` với `___` highlight
- `TextField` để nhập đáp án
- Submit → local check: `answer.trim().toLowerCase().contains(detail.correctAnswers['1']!.toLowerCase())`
- Hiện kết quả → "Tiếp theo →" button

#### `matching`
- Render `MatchingWidget` (existing widget)
  - `pairs`: `detail.matchPairs`
  - `answers`: mutable state `Map<String,String>`
  - `onChanged`: update local answers
- Check hoàn thành: all pairs matched → "Tiếp theo →" active
- Không check đúng/sai (matching self-evident) → treated as "known"

**Advance to next:**
```dart
void _advance() {
  _knownIds.add(_queue.first.id);  // all non-quizcard = "known"
  _queue.removeFirst();
  _processedCount++;
  if (_queue.isEmpty) {
    setState(() => _sessionComplete = true);
  } else {
    _loadNextDetail();
  }
}
```

**Load next detail:**
```dart
Future<void> _loadNextDetail() async {
  setState(() { _loadingDetail = true; _currentDetail = null; });
  final raw = await widget.client.getExercise(_queue.first.id);
  setState(() {
    _currentDetail = ExerciseDetail.fromJson(raw);
    _loadingDetail = false;
  });
}
```

**App bar:**
- Back button → `showDialog` confirm "Thoát deck session?" nếu queue chưa rỗng
- Title: `typeLabel`

**Loading state (between cards):** `CircularProgressIndicator` căn giữa, small (24px)

**Session complete:** Render `_CompletionView` inline trong same screen (không navigate)

---

### 4.4 CompletionView (widget nội bộ trong DeckSessionScreen)

```dart
class _CompletionView extends StatelessWidget {
  final int knownCount;
  final int totalCount;
  final int retryCount;  // queue.length khi session end (= 0 nếu tất cả known)
  final VoidCallback onRetryRemaining;  // restart với retry pile
  final VoidCallback onDone;           // Navigator.pop()
}
```

**UI:**
- Icon 🎉 (Text widget, không dùng emoji làm icon navigation — đây là decorative)
- Title: "Hoàn thành session!"
- Stat: `"$knownCount / $totalCount"` đã biết (lớn, color: primary)
- Pills: "✓ Đã biết: N" (green) + "↻ Ôn lại: N" (amber) nếu retryCount > 0
- Primary button: "↻ Ôn lại $retryCount từ còn lại" (visible chỉ khi retryCount > 0)
- Secondary button: "Xong — về danh sách" → `Navigator.pop()`

**Retry logic:** `onRetryRemaining` → DeckSessionScreen reset queue với chỉ exercises chưa known. Hiện tại với Anki loop, khi queue empty thì tất cả đều known (retryCount luôn = 0). Button chỉ cần cho tương lai hoặc matching/fill_blank edge cases.

---

## 5. Entry Point Change

**File:** `flutter_app/lib/features/course/screens/module_detail_screen.dart`

**Current behavior (line ~123):**
```dart
onTap: sk.isImplemented ? () => Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => ExerciseListScreen(
    client: widget.client,
    moduleId: widget.module.id,
    skillKind: sk.skillKind,
  )),
) : null,
```

**New behavior:**
```dart
onTap: sk.isImplemented ? () {
  final isVocabGrammar = sk.skillKind == 'tu_vung' || sk.skillKind == 'ngu_phap';
  if (isVocabGrammar) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TypeGroupScreen(
        client: widget.client,
        moduleId: widget.module.id,
        skillKind: sk.skillKind,
        moduleTitle: widget.module.title,
      ),
    ));
  } else {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExerciseListScreen(
        client: widget.client,
        moduleId: widget.module.id,
        skillKind: sk.skillKind,
      ),
    ));
  }
} : null,
```

---

## 6. API Usage

**Existing endpoint, không thay đổi:**
```
GET /v1/modules/:moduleId/exercises?skill_kind=tu_vung
GET /v1/exercises/:id   (load full ExerciseDetail for deck)
```

**Không gọi:**
- `POST /v1/attempts` — deck mode local only
- `POST /v1/attempts/:id/submit-answers` — không cần

---

## 7. Local Scoring Logic

| Type | Check | "Đã biết" condition |
|---|---|---|
| `quizcard_basic` | Self-assessed | user chọn "Đã biết" |
| `choice_word` | `tappedKey == correctAnswers['1']` | xem kết quả → next |
| `fill_blank` | `answer.toLowerCase().contains(correct.toLowerCase())` | xem kết quả → next |
| `matching` | all pairs connected | MatchingWidget completes → next |

Note: Với `choice_word`/`fill_blank`/`matching`, sau khi xem kết quả (đúng hay sai) đều advance. Không có "Ôn lại" cho các loại này — matching đã tự inherently là interactive.

---

## 8. Không Làm (Scope Boundary)

| Item | Lý do |
|---|---|
| Attempt API calls trong deck | Chậm, không cần offline work |
| SM-2 spaced repetition | Over-engineering cho V1 |
| Cross-session progress | No persistence needed |
| Audio trong deck mode | Deferred |
| Backend / CMS changes | Không cần |
| Deck mode cho noi/nghe/doc/viet | Chỉ vocab/grammar types |
| ExerciseListScreen thay đổi | Không touch file hiện tại |

---

## 9. Testing

### Widget tests (mới)
- `TypeGroupScreen`: render 4 cards với count, tap navigates
- `VocabTypeListScreen`: "Bắt đầu học tất cả" visible, tap exercises navigates
- `DeckSessionScreen` quizcard: flip → show actions → Đã biết removes from queue
- `DeckSessionScreen` quizcard: Ôn lại → card appears later, progress unchanged
- `DeckSessionScreen`: queue empty → CompletionView renders
- `_CompletionView`: knownCount/totalCount display correct

### Manual test (iOS simulator)
- Tu_vung skill → TypeGroupScreen (không còn ExerciseListScreen)
- Flashcard deck: flip animation, Đã biết/Ôn lại, progress bar, completion
- Choice word deck: tap option, feedback, advance
- Fill blank deck: type, submit, advance
- Matching deck: all pairs → advance
- Back button mid-session: confirm dialog

---

## 10. Acceptance Criteria

- [ ] Tap "Từ vựng" hoặc "Ngữ pháp" từ module detail → TypeGroupScreen (không còn ExerciseListScreen)
- [ ] TypeGroupScreen hiện đúng count theo exerciseType
- [ ] Tap type card → VocabTypeListScreen với "Bắt đầu học tất cả (N)" button
- [ ] Tap individual exercise → VocabGrammarExerciseScreen (unchanged behavior)
- [ ] "Bắt đầu học tất cả" → DeckSessionScreen với toàn bộ exercises của type đó
- [ ] Quizcard: tap flip → hiện mặt sau → unlock Đã biết/Ôn lại buttons
- [ ] Đã biết: card bị remove, queue giảm, progress tăng
- [ ] Ôn lại: card đẩy về cuối queue, progress không tăng
- [ ] Khi queue rỗng → CompletionView (không navigate, render inline)
- [ ] CompletionView "Xong" → pop về TypeGroupScreen
- [ ] Không có API attempt calls trong deck session (verify bằng network log)
- [ ] `flutter analyze` pass, `flutter test` pass

---

## 11. Implementation Order

1. `TypeGroupScreen` + entry point change trong `module_detail_screen.dart`
2. `VocabTypeListScreen` + `_openExercise` helper (reuse pattern từ ExerciseListScreen)
3. `DeckSessionScreen` core: quizcard_basic flow + CompletionView
4. `DeckSessionScreen`: thêm choice_word + fill_blank + matching support
5. Widget tests
