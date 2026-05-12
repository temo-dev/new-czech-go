# V36 Interview-in-Mock-Exam — Plan

> **Status**: 🟡 draft 2026-05-12.
>
> **Spec**: [`docs/specs/v36-interview-in-mock-exam.md`](../docs/specs/v36-interview-in-mock-exam.md).
>
> **Todo**: [`v36-interview-in-mock-exam-todo.md`](v36-interview-in-mock-exam-todo.md).

---

## Phase A — CMS authoring (~0.5 ngày)

**Goal**: Author có thể gán interview exercise vào mock test section qua dashboard.

### A.1 Update SKILL_GROUPS
- File: `cms/components/mock-test-dashboard.tsx`.
- Extend `SkillKind` type với `| 'interview'`.
- Push entry mới vào `SKILL_GROUPS` (kind=interview, color #0891B2, prefix `interview_`).
- Thêm `EXERCISE_TYPE_LABEL` 2 entry.
- Thêm `EXERCISE_TYPE_MAX_POINTS` 2 entry (=20 mỗi loại).
- Picker filter line 606 không sửa (auto-match qua prefix).

### A.2 Lint + build verify
- `make cms-lint` + `make cms-build`.

### A.3 CMS test extend
- `cms/components/__tests__/mock-test-dashboard.test.tsx`: thêm test render tab interview + payload save.

### A.4 Smoke
- `npm run dev` trong cms; tạo mock test mới với 1 interview section; save + reload OK.

**Acceptance**: tab interview hiển thị, picker chỉ list interview pool=exam, save payload contains `skill_kind='interview'`.

---

## Phase B — Flutter runner (~1 ngày)

**Goal**: Learner mock exam runner xử lý được interview section.

### B.1 Intro screen
- `flutter_app/lib/features/mock_exam/screens/mock_test_intro_screen.dart`.
- `_skillKindOrder` thêm `'interview'`.
- Verify group label render qua `_skillLabel`.

### B.2 ARB key
- `flutter_app/lib/l10n/app_vi.arb` + `app_en.arb`: thêm `"skillInterview"`.
- Run `flutter gen-l10n` (hoặc make target).
- Verify VI=EN key count.

### B.3 Runner dispatcher
- `flutter_app/lib/features/mock_exam/screens/mock_exam_screen.dart`.
- `_skillKindForExerciseType`: thêm prefix `interview_`.
- `_skillLabel`: thêm case `'interview'`.
- `_runSection`: thêm branch `kind == 'interview'` push InterviewSessionScreen với onSessionEnded.
- `_bulkAnalyze`: confirm chỉ chạm `_pendingAnalyses` (noi-only).

### B.4 InterviewSessionScreen exam-mode hook
- `flutter_app/lib/features/interview/screens/interview_session_screen.dart`.
- Thêm optional param `void Function(String attemptId)? onSessionEnded`.
- Fire sau `submit-interview` complete + LLM review xong.
- Course flow không pass callback → no-op (backward compat).

### B.5 Result card fallback
- `flutter_app/lib/features/mock_exam/widgets/section_result_card.dart`.
- Verify fallback path render interview transcript + feedback.
- Nếu generic render thiếu — thêm branch `skillKind=='interview'` (MVP simple).

### B.6 Analyze + test
- `make flutter-analyze` xanh.
- `flutter_app/test/features/mock_exam/mock_exam_screen_test.dart`: extend.
- `make flutter-test` xanh.

**Acceptance**: intro screen liệt kê 5 nhóm; tap interview → session chạy; session xong → advance → kế tiếp; toàn bộ test xong → result hiển thị overall_score đầy đủ.

---

## Phase C — Backend verify + tests (~0.5 ngày)

**Goal**: Đảm bảo scoring + advance không gãy với interview section.

### C.1 New integration test
- `backend/internal/httpapi/mock_exam_interview_section_test.go` (new).
- Test 1: tạo mock_test với 1 interview section, advance + complete attempt với score 16/20, verify overall_score=80, passed=true.
- Test 2: free-tier cap reached → 429 khi tạo interview attempt giữa exam.
- Test 3: nhiều interview section (2 sections, mỗi 20 pts) — overall_score đúng aggregate.

### C.2 Verify run
- `make backend-test`.
- Test count tăng 3.

**Acceptance**: backend test green; overall_score formula đúng; rate limit visible.

---

## Phase D — Docs + ship (~0.25 ngày)

**Goal**: CHANGELOG + SPEC.md + reference updates.

### D.1 CHANGELOG
- `CHANGELOG.md`: thêm entry V36 mới nhất, mô tả CMS group + Flutter dispatcher + backend test, list files changed, test counts before/after.

### D.2 SPEC digest
- `SPEC.md`: row V36 (date, scope, files touched count).

### D.3 Reference fold
- `docs/reference/content-and-attempt-model.md`: cập nhật mock test section skill_kind list (`noi/nghe/doc/viet/interview`).

### D.4 Idea status update
- `docs/ideas/v36-interview-in-mock-exam.md`: đổi Status thành "✅ promoted to spec on YYYY-MM-DD".

### D.5 Plan/todo index
- `tasks/plan.md`: thêm row V36.
- `tasks/todo.md`: thêm row V36 hoặc remove khi done.

### D.6 Full verify
- `make verify`.

**Acceptance**: docs đầy đủ; verify xanh; commit + push.

---

## Phase E — Smoke (~0.25 ngày)

**Goal**: Validate end-to-end trên simulator.

### E.1 Seed
- Tạo 1 interview_conversation pool=exam exercise qua CMS.
- Tạo 1 mock test mới với 1 interview section + 1 cteni section.

### E.2 iOS simulator
- Run Flutter app trên iPhone 17 Pro Max simulator.
- Login user.
- Vào mock test → start → làm cteni section → tới interview section → chạy InterviewSessionScreen → kết thúc → advance → result screen.
- Verify overall_score, transcript, feedback render đúng.

### E.3 Bug capture
- Note bất kỳ regression nào → tạo todo V37 nếu out of scope V36.

**Acceptance**: end-to-end pass; không regression; smoke ghi nhận.

---

## Total estimate

- Phase A: 0.5 ngày
- Phase B: 1 ngày
- Phase C: 0.5 ngày
- Phase D: 0.25 ngày
- Phase E: 0.25 ngày
- **Total**: ~2.5 ngày

## Sequence

A → B → C → D → E. Phase B đầu việc kiểm tra `InterviewSessionScreen` đã expose hook callback chưa; nếu chưa, B.4 + B.5 mất nhiều thời gian hơn estimate.
