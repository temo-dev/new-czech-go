# Plan: Flexible Sprint MockTest

Source: `docs/ideas/flexible-sprint-mocktest.md`
Status: Ready to implement
Date: 2026-04-29

---

## Tổng quan

Cho phép admin tạo đề luyện ngắn (sprint) với bất kỳ tổ hợp exercise types nào
(nói/nghe/đọc/viết), tự chọn số section, và đặt ngưỡng pass riêng (mặc định 80%).

---

## Quyết định kiến trúc

| Quyết định | Lý do |
|---|---|
| `pass_threshold_percent` lưu vào `mock_exam_sessions` lúc tạo | Immutable sau khi session tạo; không cần join MockTest khi complete |
| `session_type` giữ nguyên trong model, bỏ khỏi CMS form | Backward compat với data cũ; mọi đề mới đều là "sprint" (general) |
| Flutter: speaking sections → bulk analyze; non-speaking → submit ngay | Speaking cần upload audio + poll; listening/reading/writing là sync |
| Non-speaking screens: thêm `onSectionComplete(String attemptId)` callback | Surgical change, không vỡ luồng course practice hiện tại |
| Không thay đổi `FullExamSession` (pisemna/ustni split) | Full A2 chuẩn vẫn giữ nguyên, sprint dùng `MockExamSession` đơn giản |

---

## Dependency graph

```
S1 Backend (contracts + DB + scoring)
  └── S2a CMS form update          [có thể parallel với S1 nếu API mock]
  └── S2b Flutter non-speaking screens callback
        └── S3 Flutter MockExamScreen routing (cần S2b done)
```

S1 → S2a parallel → S3 sau khi S2a+S2b xong.

---

## Slices

### S1 — Backend: `pass_threshold_percent` + scoring

**Files chính:**
- `backend/internal/contracts/types.go`
- `backend/internal/store/postgres_mock_tests.go`
- `backend/internal/store/postgres_mock_exams.go`
- `backend/internal/store/mock_exam_store.go` (memory)
- `backend/internal/store/memory.go` (computeScoring)

**Thay đổi:**

1. `contracts/types.go` — Thêm field vào `MockTest`:
   ```go
   PassThresholdPercent int `json:"pass_threshold_percent"` // default 60; sprint dùng 80
   ```
   Thêm field vào `MockExamSession` (lưu lúc tạo):
   ```go
   PassThresholdPercent int `json:"pass_threshold_percent,omitempty"`
   ```

2. `postgres_mock_tests.go`:
   - `ensureSchema`: `ALTER TABLE mock_tests ADD COLUMN IF NOT EXISTS pass_threshold_percent INTEGER NOT NULL DEFAULT 60`
   - `CreateMockTest` INSERT: thêm `pass_threshold_percent`
   - `UpdateMockTest` UPDATE: thêm `pass_threshold_percent`
   - `ListMockTests` / `MockTestByID` SELECT: thêm column

3. `postgres_mock_exams.go`:
   - `ensureSchema`: `ALTER TABLE mock_exam_sessions ADD COLUMN IF NOT EXISTS pass_threshold_percent INTEGER NOT NULL DEFAULT 60`
   - `CreateMockExam`: đọc threshold từ MockTest, INSERT vào session
   - `CompleteMockExam`: đọc `pass_threshold_percent` từ session row, truyền vào `computeScoring`

4. `mock_exam_store.go` (memory) + `memory.go`:
   - `memoryMockExamStore.CreateMockExam`: store threshold từ MockTest vào session
   - `memoryMockExamStore.CompleteMockExam`: dùng session.PassThresholdPercent
   - `computeScoring(levels, maxPoints []int) → computeScoring(levels, maxPoints []int, thresholdPercent int)`:
     ```go
     passed = overallScore*100 >= totalMax*thresholdPercent
     ```

**Acceptance criteria:**
- [ ] `make backend-build` passes
- [ ] `make backend-test` passes
- [ ] POST `mock-tests` với `pass_threshold_percent=80` → GET trả về 80
- [ ] CompleteMockExam với 80% threshold: overall_score=16/20 → passed=false; 17/20 → passed=true

---

### S2a — CMS: form update

**Files chính:**
- `cms/components/mock-test-dashboard.tsx`

**Thay đổi:**

1. Type `MockTest` + `FormState`: thêm `pass_threshold_percent: number`
2. `emptyForm()`: `pass_threshold_percent: 80` (default sprint)
3. Xóa `session_type` khỏi form render (giữ trong type nhưng không hiển thị)
4. Thêm input: `<input type="number" min={1} max={100} value={form.pass_threshold_percent} />`
5. `handleSubmit` payload: thêm `pass_threshold_percent`, bỏ `session_type` (hoặc hardcode `"sprint"`)
6. `openEdit`: populate `pass_threshold_percent` từ data
7. Display trong danh sách: hiển thị `pass_threshold_percent%` bên cạnh tên đề

**Acceptance criteria:**
- [ ] `make cms-lint` passes
- [ ] `make cms-build` passes
- [ ] Admin tạo đề với 5 sections (mix speaking + listening) → save → reload đúng
- [ ] `pass_threshold_percent` hiển thị trong danh sách đề

---

### S2b — Flutter: callback timing fix (Writing only)

**Phát hiện sau phân tích code:**
- `ListeningExerciseScreen`: đã có `onAttemptCompleted` callback, fires sau submit sync → **không cần thay đổi**
- `ReadingExerciseScreen`: đã có `onAttemptCompleted` callback, fires sau submit sync → **không cần thay đổi**
- `WritingExerciseScreen`: đã có `onAttemptCompleted` callback, **nhưng fires trước** khi push AnalysisScreen (attempt còn đang processing)

**Files chính:**
- `flutter_app/lib/features/exercise/screens/writing_exercise_screen.dart` (chỉ file này)

**Thay đổi — 1 line move trong `_submit()`:**

```dart
// TRƯỚC (line ~101): callback fires trước khi LLM xong
widget.onAttemptCompleted?.call(attemptId);   // ← sai
await Navigator.of(context).push(AnalysisScreen(attemptId: attemptId, ...));

// SAU: callback fires SAU khi AnalysisScreen pop (writing đã scored)
await Navigator.of(context).push(AnalysisScreen(attemptId: attemptId, ...));
if (mounted) widget.onAttemptCompleted?.call(attemptId);  // ← đúng
```

Tại sao đúng: `_WritingResultPoller` trong AnalysisScreen chỉ pop sau khi
`attempt.status == 'completed'` — nên khi callback fires, writing đã có score.

Normal course practice không bị ảnh hưởng (không ai pass `onAttemptCompleted` trong đó).

**Acceptance criteria:**
- [ ] `make flutter-analyze` passes
- [ ] Trong course practice (WritingExerciseScreen không có callback), flow không đổi
- [ ] Trong sprint mock exam: writing callback fires AFTER analysis screen pops

---

### S3 — Flutter: MockExamScreen mixed routing

**Files chính:**
- `flutter_app/lib/features/mock_exam/screens/mock_exam_screen.dart`
- `flutter_app/lib/models/models.dart` (thêm `passThresholdPercent`)

**Thay đổi:**

1. `models.dart` — `MockExamSessionView`: thêm `passThresholdPercent` từ response

2. `mock_exam_screen.dart` — helper function:
   ```dart
   String _skillKind(String exerciseType) {
     if (exerciseType.startsWith('uloha_')) return 'noi';
     if (exerciseType.startsWith('poslech_')) return 'nghe';
     if (exerciseType.startsWith('cteni_')) return 'doc';
     if (exerciseType.startsWith('psani_')) return 'viet';
     return 'noi'; // fallback
   }
   ```

3. `_runSection()` — route theo skill kind. Callback names đã tồn tại:
   - `noi`  → `ExerciseScreen(onRecordingReady: ...)` — existing flow, add to `_pendingAnalyses`
   - `nghe` → `ListeningExerciseScreen(onAttemptCompleted: (id) async { await _advanceSection(id); })`
   - `doc`  → `ReadingExerciseScreen(onAttemptCompleted: (id) async { await _advanceSection(id); })`
   - `viet` → `WritingExerciseScreen(onAttemptCompleted: (id) async { await _advanceSection(id); })`

4. Helper `_advanceSection(String attemptId)` — gọi sau khi callback fires (trong background, không block UI):
   ```dart
   Future<void> _advanceSection(String attemptId) async {
     final payload = await widget.client.advanceMockExam(_session!.id, attemptId: attemptId);
     if (!mounted) return;
     setState(() { _session = MockExamSessionView.fromJson(payload); });
     // Không gọi _bulkAnalyze ở đây — chờ user pop về MockExamScreen
   }
   ```

5. Sau khi `Navigator.push` trả về (user pop về MockExamScreen) — check trong `_runSection`:
   ```dart
   // After await navigator.push(...) returns:
   if (!mounted) return;
   if (_session!.nextPending == null) await _bulkAnalyze();
   ```
   `_bulkAnalyze` với `_pendingAnalyses` rỗng (no speaking) → chỉ gọi `_finalize()` → đúng.

6. Result display — hiển thị `passThresholdPercent` trong result view nếu khác 60:
   - `"Ngưỡng đạt: X%"` nhỏ bên dưới overall score

**Acceptance criteria:**
- [ ] `make flutter-analyze` passes
- [ ] Sprint exam với 1 speaking + 1 listening section: speaking flow ghi âm đúng; listening flow submit answers đúng
- [ ] Sau khi xong cả 2 sections, completeMockExam được gọi
- [ ] Result screen hiển thị passed/failed dựa trên 80% threshold
- [ ] Course practice flow không bị ảnh hưởng

---

## Checkpoint cuối

```bash
make backend-build
make backend-test
make cms-lint
make cms-build
make flutter-analyze
make flutter-test
```

---

## Not doing

- `session_type` UI trong CMS — bỏ, mọi đề mới đều là general
- Per-section threshold — quá phức tạp
- `FullExamSession` redesign — không đụng vào
- Tự động chọn exercises theo thời gian — admin tự chọn

---

## Quyết định đã resolve

1. **Callback timing (đã giải quyết)**
   - Listening/Reading: fires ngay sau submit sync — OK, không block UX (kết quả hiển thị sau)
   - Writing: di chuyển callback xuống sau `await Navigator.push(AnalysisScreen)` — ensures LLM done
   - `_advanceSection` chạy trong background khi user đang đọc kết quả → không chặn UI

2. **`session_type` hardcode:** CMS bỏ field, backend default `""` nếu không có trong payload.
   Data cũ giữ nguyên `speaking/pisemna/full`, đề mới để trống.
