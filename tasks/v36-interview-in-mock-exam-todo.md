# V36 Interview-in-Mock-Exam — Todo

> **Status**: ✅ Phase A-D shipped 2026-05-12. Phase E iOS simulator
> smoke remains operator-side.
>
> **Plan**: [`v36-interview-in-mock-exam-plan.md`](v36-interview-in-mock-exam-plan.md).
>
> **Spec**: [`../docs/specs/v36-interview-in-mock-exam.md`](../docs/specs/v36-interview-in-mock-exam.md).

## Phase A — CMS

- [x] A.1 `cms/components/mock-test-dashboard.tsx` — extend `SkillKind` type với `'interview'`.
- [x] A.2 Same file — push `SKILL_GROUPS` entry (kind=interview, color #0891B2, prefix `interview_`, label "Hội thoại AI").
- [x] A.3 Same file — `EXERCISE_TYPE_LABEL` thêm 2 entry (interview_conversation, interview_choice_explain).
- [x] A.4 Same file — `EXERCISE_TYPE_MAX_POINTS` thêm 2 entry (=20).
- [x] A.5 `make cms-lint` xanh.
- [x] A.6 `make cms-build` xanh.
- [x] A.7 `cms/components/__tests__/mock-test-dashboard.test.tsx` — test render tab interview + save payload.
- [x] A.8 `cd cms && npm test` xanh.
- [x] A.9 Local smoke — create mock test với 1 interview section, save + reload.

## Phase B — Flutter

- [x] B.1 `flutter_app/lib/features/mock_exam/screens/mock_test_intro_screen.dart` — `_skillKindOrder` thêm `'interview'`.
- [x] B.2 `flutter_app/lib/l10n/app_vi.arb` — thêm `"skillInterview": "Hội thoại AI"`.
- [x] B.3 `flutter_app/lib/l10n/app_en.arb` — thêm `"skillInterview": "AI Conversation"`.
- [x] B.4 `flutter gen-l10n` (hoặc make target tương đương).
- [x] B.5 `flutter_app/lib/features/mock_exam/screens/mock_exam_screen.dart` — `_skillKindForExerciseType` thêm branch `interview_`.
- [x] B.6 Same file — `_skillLabel` switch thêm case `'interview'`.
- [x] B.7 Same file — `_runSection` thêm branch `kind == 'interview'` push InterviewSessionScreen với onSessionEnded.
- [x] B.8 `flutter_app/lib/features/interview/screens/interview_session_screen.dart` — thêm optional callback `onSessionEnded`.
- [x] B.9 `flutter_app/lib/features/mock_exam/widgets/section_result_card.dart` — verify fallback render interview transcript + feedback.
- [x] B.10 `make flutter-analyze` xanh.
- [x] B.11 `flutter_app/test/features/mock_exam/mock_exam_screen_test.dart` — extend test.
- [x] B.12 `make flutter-test` xanh.

## Phase C — Backend

- [x] C.1 `backend/internal/httpapi/mock_exam_interview_section_test.go` (new) — Test 1: end-to-end overall_score.
- [x] C.2 Same file — Test 2: free-tier cap 429.
- [x] C.3 Same file — Test 3: multiple interview section aggregate.
- [x] C.4 `make backend-test` xanh; test count tăng 3.

## Phase D — Docs

- [x] D.1 `CHANGELOG.md` — thêm entry V36 mới nhất.
- [x] D.2 `SPEC.md` — thêm row V36.
- [x] D.3 `docs/reference/content-and-attempt-model.md` — cập nhật mock test section skill_kind list.
- [x] D.4 `docs/ideas/v36-interview-in-mock-exam.md` — đổi Status sang "✅ promoted to spec on YYYY-MM-DD".
- [x] D.5 `docs/specs/v36-interview-in-mock-exam.md` — đổi Status sang "✅ frozen on YYYY-MM-DD".
- [x] D.6 `tasks/plan.md` — add V36 row.
- [x] D.7 `tasks/todo.md` — add V36 row (sau remove khi done).
- [x] D.8 `make verify` toàn bộ xanh.

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
