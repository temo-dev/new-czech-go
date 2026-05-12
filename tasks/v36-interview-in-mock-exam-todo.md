# V36 Interview-in-Mock-Exam — Todo

> **Status**: 🟡 draft 2026-05-12.
>
> **Plan**: [`v36-interview-in-mock-exam-plan.md`](v36-interview-in-mock-exam-plan.md).
>
> **Spec**: [`../docs/specs/v36-interview-in-mock-exam.md`](../docs/specs/v36-interview-in-mock-exam.md).

## Phase A — CMS

- [ ] A.1 `cms/components/mock-test-dashboard.tsx` — extend `SkillKind` type với `'interview'`.
- [ ] A.2 Same file — push `SKILL_GROUPS` entry (kind=interview, color #0891B2, prefix `interview_`, label "Hội thoại AI").
- [ ] A.3 Same file — `EXERCISE_TYPE_LABEL` thêm 2 entry (interview_conversation, interview_choice_explain).
- [ ] A.4 Same file — `EXERCISE_TYPE_MAX_POINTS` thêm 2 entry (=20).
- [ ] A.5 `make cms-lint` xanh.
- [ ] A.6 `make cms-build` xanh.
- [ ] A.7 `cms/components/__tests__/mock-test-dashboard.test.tsx` — test render tab interview + save payload.
- [ ] A.8 `cd cms && npm test` xanh.
- [ ] A.9 Local smoke — create mock test với 1 interview section, save + reload.

## Phase B — Flutter

- [ ] B.1 `flutter_app/lib/features/mock_exam/screens/mock_test_intro_screen.dart` — `_skillKindOrder` thêm `'interview'`.
- [ ] B.2 `flutter_app/lib/l10n/app_vi.arb` — thêm `"skillInterview": "Hội thoại AI"`.
- [ ] B.3 `flutter_app/lib/l10n/app_en.arb` — thêm `"skillInterview": "AI Conversation"`.
- [ ] B.4 `flutter gen-l10n` (hoặc make target tương đương).
- [ ] B.5 `flutter_app/lib/features/mock_exam/screens/mock_exam_screen.dart` — `_skillKindForExerciseType` thêm branch `interview_`.
- [ ] B.6 Same file — `_skillLabel` switch thêm case `'interview'`.
- [ ] B.7 Same file — `_runSection` thêm branch `kind == 'interview'` push InterviewSessionScreen với onSessionEnded.
- [ ] B.8 `flutter_app/lib/features/interview/screens/interview_session_screen.dart` — thêm optional callback `onSessionEnded`.
- [ ] B.9 `flutter_app/lib/features/mock_exam/widgets/section_result_card.dart` — verify fallback render interview transcript + feedback.
- [ ] B.10 `make flutter-analyze` xanh.
- [ ] B.11 `flutter_app/test/features/mock_exam/mock_exam_screen_test.dart` — extend test.
- [ ] B.12 `make flutter-test` xanh.

## Phase C — Backend

- [ ] C.1 `backend/internal/httpapi/mock_exam_interview_section_test.go` (new) — Test 1: end-to-end overall_score.
- [ ] C.2 Same file — Test 2: free-tier cap 429.
- [ ] C.3 Same file — Test 3: multiple interview section aggregate.
- [ ] C.4 `make backend-test` xanh; test count tăng 3.

## Phase D — Docs

- [ ] D.1 `CHANGELOG.md` — thêm entry V36 mới nhất.
- [ ] D.2 `SPEC.md` — thêm row V36.
- [ ] D.3 `docs/reference/content-and-attempt-model.md` — cập nhật mock test section skill_kind list.
- [ ] D.4 `docs/ideas/v36-interview-in-mock-exam.md` — đổi Status sang "✅ promoted to spec on YYYY-MM-DD".
- [ ] D.5 `docs/specs/v36-interview-in-mock-exam.md` — đổi Status sang "✅ frozen on YYYY-MM-DD".
- [ ] D.6 `tasks/plan.md` — add V36 row.
- [ ] D.7 `tasks/todo.md` — add V36 row (sau remove khi done).
- [ ] D.8 `make verify` toàn bộ xanh.

## Phase E — Smoke

- [ ] E.1 Seed 1 interview_conversation pool=exam qua CMS.
- [ ] E.2 Tạo mock test với 1 interview section + 1 cteni section.
- [ ] E.3 Run Flutter trên iPhone 17 Pro Max simulator (MobAI/manual).
- [ ] E.4 Login + làm full flow → cteni → interview → result.
- [ ] E.5 Verify overall_score + transcript + feedback render đúng.
- [ ] E.6 Note regression (nếu có) → tạo V37 todo.

## Commit chunks (recommended)

1. Phase A: "feat(v36): cms mock-test-dashboard expose interview group"
2. Phase B (sub-1): "feat(v36): flutter mock-exam intro + label support interview"
3. Phase B (sub-2): "feat(v36): flutter mock-exam runner dispatch interview section"
4. Phase B (sub-3): "feat(v36): interview session expose onSessionEnded hook"
5. Phase C: "test(v36): backend mock-exam interview section integration"
6. Phase D: "docs(v36): changelog + spec digest + reference fold"
7. Phase E (post-ship): smoke note in CHANGELOG comment nếu cần.
