# V36 Interview-in-Mock-Exam — Spec

> **Status**: ✅ frozen on 2026-05-12 (slice shipped). Future changes
> land in a later slice + reference fold, not by editing this file.
>
> **Linked idea**: [`docs/ideas/v36-interview-in-mock-exam.md`](../ideas/v36-interview-in-mock-exam.md).
>
> **Plan**: [`tasks/v36-interview-in-mock-exam-plan.md`](../../tasks/v36-interview-in-mock-exam-plan.md).
>
> **Todo**: [`tasks/v36-interview-in-mock-exam-todo.md`](../../tasks/v36-interview-in-mock-exam-todo.md).

---

## 1. Slice Goal

Mở interview (`interview_conversation` + `interview_choice_explain`) thành skill thứ 5 trong mock test, ngang hàng noi/nghe/doc/viet. Author có thể gán interview exercise vào mock test section qua CMS. Learner làm mock exam thấy + chạy được interview section. Backend cộng điểm interview vào overall_score.

---

## 2. Decisions (frozen)

| # | Decision | Rationale |
|---|---|---|
| D1 | Thêm `interview` thành skill_kind thứ 5; không replace `noi`. | Tránh phá Úloha 1-4 đang dùng. Interview là format khác (free-talk AI). |
| D2 | CMS tab interview đặt sau tab Viết. | Parity vị trí với course list view. |
| D3 | Result card MVP dùng fallback generic; không viết InterviewResultCard riêng. | Defer tới khi có user feedback từ pilot. |
| D4 | Default `max_points` cho cả 2 interview type = 20. | Parity với Úloha 1 (single skill block). |
| D5 | Không enforce min per-skill score; tính pass theo % overall. | MVP simple; revisit khi có data. |
| D6 | Cho phép multiple interview section trong 1 test (technical-allow). | Weekly cap V17 đã chặn spam. |
| D7 | Không schema migration. `mock_test_sections.skill_kind` đã TEXT free-form. | Backward compat tự nhiên. |
| D8 | Free-tier weekly interview cap đếm chung course + exam attempt. | Cap là per-attempt, không phân biệt context. |
| D9 | Bulk-analyze chỉ áp dụng cho `noi` (uloha_*); interview self-score qua `submit-interview` ngay khi session đóng. | Interview đã score trong session lifecycle, không lưu pending. |

---

## 3. Contracts

### 3.1 Backend

**Không đổi shape:**
- `MockTestSection` JSON shape (sequence_no, skill_kind, exercise_id, exercise_type, max_points). `skill_kind="interview"` hợp lệ.
- `POST /v1/mock-exam-sessions/:id/advance` (existing) accept attempt với exercise.SkillKind="interview".
- `POST /v1/attempts/:id/submit-interview` (existing) trigger LLM review ghi `attempt.score`.
- `mock_exam_sessions.overall_score` computation: sum(attempt.score) / sum(section.max_points) × 100.

**Verify (không sửa code):**
- `submit-interview` set `attempt.score` đúng range 0..max_points.
- `advance` không reject section interview.
- Free-tier cap (server.go:1702-1717) đếm cùng counter cho course + exam attempts.

### 3.2 CMS

**File**: `cms/components/mock-test-dashboard.tsx`.

```ts
type SkillKind = 'noi' | 'nghe' | 'doc' | 'viet' | 'interview';

const SKILL_GROUPS: { kind: SkillKind; label: string; color: string; prefix: string }[] = [
  { kind: 'noi',       label: 'Nói (Speaking)',    color: '#FF6A14', prefix: 'uloha_' },
  { kind: 'nghe',      label: 'Nghe (Listening)',  color: '#3060B8', prefix: 'poslech_' },
  { kind: 'doc',       label: 'Đọc (Reading)',     color: '#C28012', prefix: 'cteni_' },
  { kind: 'viet',      label: 'Viết (Writing)',    color: '#1F8A4D', prefix: 'psani_' },
  { kind: 'interview', label: 'Hội thoại AI',      color: '#0891B2', prefix: 'interview_' },
];

const EXERCISE_TYPE_LABEL: Record<string, string> = {
  // …existing…
  interview_conversation:   'Hội thoại theo chủ đề',
  interview_choice_explain: 'Chọn phương án + giải thích',
};

const EXERCISE_TYPE_MAX_POINTS: Record<string, number> = {
  // …existing…
  interview_conversation:   20,
  interview_choice_explain: 20,
};
```

**Picker filter**: line 606 hiện `exercises.filter(ex => ex.exercise_type.startsWith(group.prefix))` — tự nhiên match khi thêm group `interview`. Không sửa.

### 3.3 Flutter

**File**: `flutter_app/lib/features/mock_exam/screens/mock_test_intro_screen.dart`.

```dart
static const _skillKindOrder = ['noi', 'nghe', 'doc', 'viet', 'interview'];
```

**File**: `flutter_app/lib/features/mock_exam/screens/mock_exam_screen.dart`.

```dart
String _skillKindForExerciseType(String exerciseType) {
  if (exerciseType.startsWith('uloha_')) return 'noi';
  if (exerciseType.startsWith('poslech_')) return 'nghe';
  if (exerciseType.startsWith('cteni_')) return 'doc';
  if (exerciseType.startsWith('psani_')) return 'viet';
  if (exerciseType.startsWith('interview_')) return 'interview';
  return 'noi';
}

String _skillLabel(AppLocalizations l, String skillKind) => switch (skillKind) {
  'noi'       => l.skillNoi,
  'nghe'      => l.skillNghe,
  'doc'       => l.skillDoc,
  'viet'      => l.skillViet,
  'interview' => l.skillInterview,
  _ => skillKind.toUpperCase(),
};
```

**`_runSection` interview branch** (sau branch noi, trước else non-speaking):

```dart
if (kind == 'interview') {
  await navigator.push(
    MaterialPageRoute(
      builder: (_) => InterviewSessionScreen(
        client: widget.client,
        detail: detail,
        examMode: true,
        onSessionEnded: (attemptId) async {
          await _advanceSection(attemptId);
        },
      ),
    ),
  );
  if (!mounted) return;
} else if (kind == 'noi') {
  // …existing speaking branch…
} else {
  // …existing nghe/doc/viet branch…
}
```

**ARB** (`flutter_app/lib/l10n/app_vi.arb` + `app_en.arb`):

```json
"skillInterview": "Hội thoại AI"
"skillInterview": "AI Conversation"
```

**InterviewSessionScreen onSessionEnded hook**: hiện chưa có. Thêm optional callback param `void Function(String attemptId)? onSessionEnded`; fire sau khi `submit-interview` complete + LLM review xong. Course flow (intro screen) không pass callback → no-op.

### 3.4 Section Result Card

`SectionResultCard` (`flutter_app/lib/features/mock_exam/widgets/section_result_card.dart`) line 21 đã có comment "skillKind may be empty — falls back via result.exerciseType prefix". Verify fallback path: render `result.transcript` + `result.feedback` cho interview. Nếu generic render đủ → no change.

---

## 4. Test Plan

### Backend (`backend/internal/httpapi/mock_exam_interview_section_test.go` — new)

1. Setup: 1 interview_conversation exercise pool=exam, 1 mock_test với 1 section interview (max_points=20).
2. POST `/v1/mock-exam-sessions` start session.
3. POST `/v1/attempts` create interview attempt.
4. Mock ElevenLabs + LLM review → attempt.score=16.
5. POST `/v1/attempts/:id/submit-interview` complete.
6. POST `/v1/mock-exam-sessions/:id/advance` with interview attemptId.
7. Verify session.overall_score = 16/20 × 100 = 80.0.
8. Verify session.passed = true (default threshold 80%).

### CMS (`cms/components/__tests__/mock-test-dashboard.test.tsx` — extend)

1. Render dashboard với 1 interview_conversation pool=exam exercise.
2. Assert tab "Hội thoại AI" visible.
3. Click "Thêm bài tập" trong tab interview → dropdown contains exercise.
4. Save → POST payload include section với `skill_kind='interview'`.

### Flutter (`flutter_app/test/features/mock_exam/mock_exam_screen_test.dart` — extend)

1. Test `_skillKindForExerciseType('interview_conversation')` = 'interview'.
2. Test `_skillLabel(l, 'interview')` = "Hội thoại AI".
3. Widget test: mock test với interview section → intro screen liệt kê group.
4. Integration: `_runSection` push InterviewSessionScreen khi kind='interview'.

---

## 5. Migration / Rollout

- Không cần DB migration.
- Không cần feature flag — backward compat (test không có interview section vẫn render đúng 4 group).
- Rollout: ship full stack 1 PR. Author seed 1 interview exercise pool=exam, gán vào 1 mock test, smoke test trên iPhone simulator.

---

## 6. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Free-tier user kẹt khi cap hit giữa exam | Frontend hiển thị 429 message; user phải hoàn thành exam sau. |
| Interview attempt score chưa kịp set khi advance gọi | `submit-interview` block tới khi LLM review xong; advance gọi sau onSessionEnded. |
| InterviewSessionScreen pop khi user back ngang | `onSessionEnded` không fire → `_advanceSection` không gọi → section pending → user retry. |
| Mock test test cũ break do thêm group | SKILL_GROUPS push thêm entry không phá 4 entry cũ; intro screen `_skillKindOrder` thêm cuối không đổi order existing. |

---

## 7. References

- AGENTS.md § "Product Scope".
- `docs/reference/content-and-attempt-model.md`.
- `docs/specs/interview-skill.md`.
- `backend/internal/httpapi/server.go:1672-1748`.
- `flutter_app/lib/features/interview/screens/interview_session_screen.dart`.
- `cms/components/mock-test-dashboard.tsx`.
