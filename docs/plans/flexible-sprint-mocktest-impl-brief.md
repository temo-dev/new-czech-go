# Implementation Brief: Flexible Sprint MockTest (V7)

Ngày chuẩn bị: 2026-04-29
Plan đầy đủ: `docs/plans/flexible-sprint-mocktest-plan.md`
Idea gốc: `docs/ideas/flexible-sprint-mocktest.md`

---

## Mục tiêu

Admin tạo đề luyện ngắn với bất kỳ tổ hợp exercise types nào (nói/nghe/đọc/viết),
số section tùy chọn, ngưỡng pass 80% thay vì 60% chuẩn kỳ thi.

---

## Quyết định đã frozen (không thảo luận lại)

| # | Quyết định |
|---|---|
| 1 | `pass_threshold_percent` lưu vào `mock_exam_sessions` khi tạo (immutable) |
| 2 | `session_type` bỏ khỏi CMS form, giữ trong model để không break data cũ |
| 3 | Callbacks `onAttemptCompleted` đã tồn tại trong Listening + Reading — không thêm mới |
| 4 | Writing callback: move 1 line xuống sau `await Navigator.push(AnalysisScreen)` |
| 5 | `_advanceSection` chạy background; sau user pop mới check `nextPending == null` → `_bulkAnalyze` |
| 6 | `FullExamSession` (pisemna/ustni split) giữ nguyên — không đụng vào |

---

## Thứ tự triển khai

```
SP-1 (Backend)  ──→  SP-2a (CMS)  ──→  SP-3 (Flutter routing)
                └──→  SP-2b (Flutter 1-line fix)  ──┘
```

SP-2a và SP-2b độc lập, có thể làm parallel sau SP-1.
SP-3 cần SP-2b xong trước (dùng `onAttemptCompleted`).

---

## SP-1 — Backend (Go)

**Files:**
- `backend/internal/contracts/types.go`
- `backend/internal/store/postgres_mock_tests.go`
- `backend/internal/store/postgres_mock_exams.go`
- `backend/internal/store/mock_exam_store.go`
- `backend/internal/store/memory.go`

**Thay đổi cụ thể:**

### contracts/types.go
```go
// Thêm vào MockTest:
PassThresholdPercent int `json:"pass_threshold_percent"` // 0 = use default 60

// Thêm vào MockExamSession:
PassThresholdPercent int `json:"pass_threshold_percent,omitempty"`
```

### postgres_mock_tests.go — ensureSchema
```sql
ALTER TABLE mock_tests
  ADD COLUMN IF NOT EXISTS pass_threshold_percent INTEGER NOT NULL DEFAULT 60;
```
- CreateMockTest INSERT: thêm `pass_threshold_percent`
- UpdateMockTest UPDATE SET: thêm `pass_threshold_percent=$N`
- ListMockTests + MockTestByID SELECT: thêm column

### postgres_mock_exams.go — ensureSchema
```sql
ALTER TABLE mock_exam_sessions
  ADD COLUMN IF NOT EXISTS pass_threshold_percent INTEGER NOT NULL DEFAULT 60;
```
- `CreateMockExam`: đọc `mt.PassThresholdPercent` (default 60 nếu 0), INSERT vào session
- `CompleteMockExam`: thêm SELECT `pass_threshold_percent` → truyền vào `computeScoring`

### memory.go — computeScoring signature
```go
// Cũ:
func computeScoring(levels []string, maxPoints []int) ([]int, string, int, bool)

// Mới:
func computeScoring(levels []string, maxPoints []int, thresholdPercent int) ([]int, string, int, bool)
// passed = overallScore*100 >= totalMax*thresholdPercent
```
Update tất cả callers (memory store + postgres store).

**Verify:**
```bash
make backend-build && make backend-test
```

---

## SP-2a — CMS (TypeScript/React)

**File:** `cms/components/mock-test-dashboard.tsx`

**Thay đổi:**

```typescript
// 1. Thêm vào type MockTest + FormState:
pass_threshold_percent: number;

// 2. emptyForm():
pass_threshold_percent: 80,  // default sprint

// 3. Bỏ session_type khỏi JSX form render (giữ trong type)
// 4. Thêm input mới:
<label>Ngưỡng đạt (%)</label>
<input type="number" min={1} max={100}
  value={form.pass_threshold_percent}
  onChange={e => setForm({...form, pass_threshold_percent: +e.target.value})} />

// 5. handleSubmit payload: thêm pass_threshold_percent, bỏ session_type
// 6. openEdit: set form.pass_threshold_percent = t.pass_threshold_percent ?? 80
// 7. Danh sách: hiện "X%" bên cạnh tên đề
```

**Verify:**
```bash
make cms-lint && make cms-build
```

---

## SP-2b — Flutter WritingExerciseScreen (1-line fix)

**File:** `flutter_app/lib/features/exercise/screens/writing_exercise_screen.dart`

**Thay đổi trong `_submit()`:**
```dart
// Tìm đoạn này (~line 99-103):
widget.onAttemptCompleted?.call(attemptId);   // ← XÓA DÒNG NÀY
await Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => _WritingResultPoller(...)),
);

// Thay bằng:
await Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => _WritingResultPoller(...)),
);
if (mounted) widget.onAttemptCompleted?.call(attemptId);  // ← THÊM SAU PUSH
```

Lý do: `_WritingResultPoller` poll cho đến `status=completed` mới pop — callback chỉ fires khi LLM xong.

**Verify:**
```bash
make flutter-analyze && make flutter-test
```

---

## SP-3 — Flutter MockExamScreen (routing + UX fixes)

**Files:**
- `flutter_app/lib/features/mock_exam/screens/mock_exam_screen.dart`
- `flutter_app/lib/models/models.dart`
- `flutter_app/lib/l10n/app_localizations_vi.arb` + `_en.arb`

### models.dart — MockExamSessionView
```dart
// Thêm field:
final int passThresholdPercent;

// constructor + fromJson:
passThresholdPercent: (json['pass_threshold_percent'] as num?)?.toInt() ?? 60,
```

### i18n — thêm 1 key
```json
// app_localizations_vi.arb:
"mockTestIntroPassPercent": "Cần đạt ≥{pct}%",
"@mockTestIntroPassPercent": { "placeholders": { "pct": { "type": "int" } } }

// app_localizations_en.arb:
"mockTestIntroPassPercent": "Need ≥{pct}% to pass",
```

### mock_exam_screen.dart

**1. Helper `_skillKind`:**
```dart
static String _skillKind(String exerciseType) {
  if (exerciseType.startsWith('uloha_')) return 'noi';
  if (exerciseType.startsWith('poslech_')) return 'nghe';
  if (exerciseType.startsWith('cteni_')) return 'doc';
  if (exerciseType.startsWith('psani_')) return 'viet';
  return 'noi';
}
```

**2. `_advanceSection` helper:**
```dart
Future<void> _advanceSection(String attemptId) async {
  final payload = await widget.client.advanceMockExam(_session!.id, attemptId: attemptId);
  if (!mounted) return;
  setState(() { _session = MockExamSessionView.fromJson(payload); });
}
```

**3. `_runSection` — thêm non-speaking branches:**
```dart
Future<void> _runSection(MockExamSection section) async {
  final navigator = Navigator.of(context);
  final kind = _skillKind(section.exerciseType);
  final detail = ExerciseDetail.fromJson(await widget.client.getExercise(section.exerciseId));
  if (!mounted) return;

  if (kind == 'noi') {
    // existing speaking flow — unchanged
    ...
  } else {
    // non-speaking flow
    await navigator.push(MaterialPageRoute(
      builder: (_) => switch (kind) {
        'nghe' => ListeningExerciseScreen(
            client: widget.client, detail: detail,
            onAttemptCompleted: (id) async { await _advanceSection(id); }),
        'doc'  => ReadingExerciseScreen(
            client: widget.client, detail: detail,
            onAttemptCompleted: (id) async { await _advanceSection(id); }),
        'viet' => WritingExerciseScreen(
            client: widget.client, detail: detail,
            onAttemptCompleted: (id) async { await _advanceSection(id); }),
        _ => throw StateError('Unknown skill kind: $kind'),
      },
    ));
    if (!mounted) return;
    if (_session!.nextPending == null) await _bulkAnalyze();
  }
}
```

**4. `_sectionIconBg` — thêm non-speaking:**
```dart
Color _sectionIconBg(String exerciseType) => switch (exerciseType) {
  String t when t.startsWith('uloha_1') => AppColors.primaryFixed,
  String t when t.startsWith('uloha_2') => AppColors.infoContainer,
  String t when t.startsWith('uloha_3') => AppColors.warningContainer,
  String t when t.startsWith('uloha_4') => AppColors.successContainer,
  String t when t.startsWith('poslech_') => AppColors.infoContainer,
  String t when t.startsWith('cteni_')   => AppColors.tertiaryContainer,
  String t when t.startsWith('psani_')   => AppColors.secondaryContainer,
  _ => AppColors.surfaceContainerHigh,
};
```

**5. Result view — threshold display:**
```dart
// Trong _MockExamResultView.build():
// Thêm bên dưới overall score nếu threshold != 60:
if (session.passThresholdPercent != 60)
  Text(
    l.mockTestIntroPassPercent(session.passThresholdPercent),
    style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
  ),
```

**Verify:**
```bash
make flutter-analyze && make flutter-test
```

---

## UX issues phát hiện — fix trong SP-3

| Issue | Location | Fix |
|-------|----------|-----|
| Section icon gray cho poslech/cteni/psani | `_sectionIconBg` | Đã có trong SP-3 item 4 |
| Threshold hiển thị percent | `_MockExamResultView` | Đã có trong SP-3 item 5 |
| Retry button trong sprint context | Truyền `onRetry: null` hoặc không show | Check nếu `context == mock_exam` |
| Raw hex trong `_TabBar` result_card | `result_card.dart` | **Backlog** — không trong scope SP |

---

## Checkpoint cuối

```bash
make verify
```

Manual test:
1. CMS: tạo MockTest "Sprint Nói+Nghe" với 1 uloha_1 + 1 poslech_2, pass_threshold=80
2. Flutter: chọn test → làm uloha_1 (ghi âm) → làm poslech_2 (chọn đáp án)  
3. Kết quả: hiển thị "Cần đạt ≥80%", passed/failed tính đúng theo 80%
4. Course practice (Listening, Writing screen riêng lẻ): không bị ảnh hưởng

---

## Không làm trong V7

- Retry button trong sprint context — edge case, defer
- Body font swap (Noto Sans) — ảnh hưởng toàn app, separate task
- Raw hex tokens trong `result_card.dart` — cosmetic, backlog
- Per-section pass threshold — quá phức tạp
- `FullExamSession` redesign
