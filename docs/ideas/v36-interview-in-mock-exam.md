# V36 Interview-in-Mock-Exam — Idea + Requirements

> **Status**: ✅ promoted to spec on 2026-05-12. Spec authoritative:
> `docs/specs/v36-interview-in-mock-exam.md`. Idea kept as historical
> pre-spec; nếu mâu thuẫn, theo spec.
>
> **Owner**: solo admin (tuananh.ngta@gmail.com).
>
> **Trigger**: User báo "interview exercise không assign vào exam được". Root cause: CMS mock-test-dashboard hardcode 4 SKILL_GROUPS (noi/nghe/doc/viet); Flutter intro `_skillKindOrder` + `_runSection` dispatcher cùng pattern. Backend đã accept `pool='exam'` cho interview exercise nhưng frontend không expose.

---

## 1. Problem Statement

> **HMW** cho phép author gán interview exercise vào mock test section + learner làm interview trong luồng exam như một skill thứ 5?

Hiện trạng:

| Layer | File | Hiện trạng |
|---|---|---|
| Backend pool | `server.go:2298-2307` | Accept `pool='exam'` cho mọi exercise type (kể cả interview). ✅ |
| Backend skill_kind | `server.go:2141` | Map `interview_*` → `skill_kind='interview'`. ✅ |
| Backend store | `postgres_mock_tests.go` | `mock_test_sections.skill_kind` TEXT free-form — không enum. ✅ |
| CMS dashboard | `mock-test-dashboard.tsx:81-88` | `SKILL_GROUPS` hardcode noi/nghe/doc/viet. Picker filter theo `exercise_type.startsWith(prefix)` → interview_* không match. ❌ |
| Flutter intro | `mock_test_intro_screen.dart:194` | `_skillKindOrder=['noi','nghe','doc','viet']`. Interview section bị nhét vào group fallback. ⚠️ |
| Flutter runner | `mock_exam_screen.dart:32-44,197-272` | `_skillKindForExerciseType` chỉ 4 prefix. `_runSection` dispatch noi/nghe/doc/viet, fallback WritingExerciseScreen. Interview section sẽ render sai widget. ❌ |
| Flutter label | `mock_exam_screen.dart:46-52` | `_skillLabel` switch 4 kind, fallback `toUpperCase()`. ⚠️ |
| Flutter ARB | `app_*.arb` | Không có key `skillInterview`. ❌ |
| Scoring aggregator | `postgres_mock_exams.go:365` | Sum theo `attempt.score / max_points` — interview attempt có `score` từ LLM review nên về lý thuyết plug được. ⚠️ verify cần. |

---

## 2. Recommended Direction

Mở interview thành **5th skill group** trong mock test, ngang hàng noi/nghe/doc/viet. Phạm vi tối thiểu để end-to-end chạy được.

3 phase theo thứ tự:

### A. CMS authoring (0.5 ngày)
- Thêm `interview` vào `SkillKind` type + `SKILL_GROUPS` array (prefix `interview_`, color `#0891B2` reuse từ exercise-utils).
- Thêm `EXERCISE_TYPE_LABEL` entry cho `interview_conversation` + `interview_choice_explain`.
- Default `max_points` interview = 20 (single skill block, parity với uloha_1).

### B. Flutter runner (1 ngày)
- `_skillKindOrder` + label switch thêm `interview`.
- `_skillKindForExerciseType` thêm prefix `interview_`.
- `_runSection` thêm branch `kind == 'interview'` → push `InterviewSessionScreen` với callback `onSessionEnded` → submit-interview + `_advanceSection(attemptId)`.
- `InterviewSessionScreen` đã có `onSessionEnded` hook (nếu chưa, thêm 1 callback param không phá course flow).
- ARB key `skillInterview` (VI: "Hội thoại AI", EN: "AI Conversation").

### C. Backend verify + tests (0.5 ngày)
- Test mới: tạo mock_test với 1 interview section, advance + complete attempt, verify `overall_score` cộng đúng.
- Verify free-tier weekly interview cap (server.go:1702-1717) không double-charge khi gọi từ mock exam runner — phải gọi 1 lần mỗi attempt.
- Không cần migration (`mock_test_sections.skill_kind` đã TEXT free-form).

---

## 3. Key Assumptions to Validate

- [ ] Mock test exam có nên scoring interview qua LLM rubric như course attempt? — yes, dùng cùng `submit-interview` path.
- [ ] Free-tier weekly interview cap (V17) áp dụng cả khi interview là 1 section của exam? — yes, mỗi interview attempt count, không phụ thuộc context.
- [ ] Interview section trong exam có nên block bulk-analyze speaking step không? — không, interview tự score khi `submit-interview` trả về; bulk-analyze chỉ chạm `noi` (uloha_*).
- [ ] Mock test pass threshold tính theo % overall_score, interview cộng vào tử số + mẫu số bình thường? — yes.
- [ ] `InterviewSessionScreen` có callback hook để biết khi nào session kết thúc + có `attemptId` để pass cho mock exam? — verify trong section detail.

---

## 4. MVP Scope (~2 ngày)

### IN
- CMS dashboard mở 5th group `interview` + labels.
- Flutter intro + runner + dispatcher + ARB hỗ trợ `interview` skill.
- Backend test verifies scoring + advance with interview section.
- CHANGELOG V36 entry + `SPEC.md` row.
- Update `docs/reference/content-and-attempt-model.md` nếu cần (mock test section skill_kind list).

### OUT
- Restriction: max 1 interview section per mock test (tránh weekly cap fatigue) — defer.
- Promotion exam interview gate (V21 promotion ladder) — defer cho V37.
- Interview-only mock test (5 interview prompts khác chủ đề) — defer.
- Mock exam result UI section card customization cho interview transcript — fallback dùng generic AttemptResult card hiện có.
- CMS validation: interview exercise required `system_prompt` đã có ở create path, không thêm.

---

## 5. Detailed Requirements

### 5.1 Functional — CMS

| FR | Yêu cầu |
|---|---|
| FR-A1 | `SKILL_GROUPS` thêm entry `{ kind: 'interview', label: 'Hội thoại AI', color: '#0891B2', prefix: 'interview_' }`. |
| FR-A2 | `EXERCISE_TYPE_LABEL` thêm `interview_conversation: 'Hội thoại theo chủ đề'`, `interview_choice_explain: 'Chọn phương án + giải thích'`. |
| FR-A3 | `EXERCISE_TYPE_MAX_POINTS` default `interview_conversation=20`, `interview_choice_explain=20`. |
| FR-A4 | Section type validation: skill_kind = interview thì exercise_type phải bắt đầu `interview_`. Frontend đã filter qua prefix, không cần check thêm. |

### 5.2 Functional — Flutter

| FR | Yêu cầu |
|---|---|
| FR-B1 | `_skillKindOrder` = `['noi','nghe','doc','viet','interview']`. |
| FR-B2 | `_skillKindForExerciseType` thêm `if (exerciseType.startsWith('interview_')) return 'interview';`. |
| FR-B3 | `_skillLabel` switch thêm `'interview' => l.skillInterview`. |
| FR-B4 | `_runSection` thêm branch `kind == 'interview'` → push `InterviewSessionScreen` với `client`, `detail`, `onSessionEnded(attemptId)` callback → `_advanceSection(attemptId)`. |
| FR-B5 | Bulk-analyze (`_bulkAnalyze`) chỉ chạm pending `noi` attempts; interview attempts không cộng vào `_pendingAnalyses`. |
| FR-B6 | ARB key mới `skillInterview` (VI + EN). VI count = EN count. |
| FR-B7 | `SectionResultCard` fallback cho `skillKind='interview'` — render generic transcript + LLM review từ `result.feedback`. |

### 5.3 Functional — Backend

| FR | Yêu cầu |
|---|---|
| FR-C1 | Không schema migration. `mock_test_sections.skill_kind` đã TEXT. |
| FR-C2 | Test mới `mock_exam_interview_section_test.go`: tạo mock_test với section interview, advance, submit-interview, verify `overall_score` cộng đúng max_points. |
| FR-C3 | Free-tier interview cap (V17) áp dụng cho mỗi attempt độc lập, không phân biệt context (course vs exam). Không sửa rate limit logic. |
| FR-C4 | Mock exam `advance` endpoint accept attempt với exercise.SkillKind='interview'. Verify hiện tại có blocker không. |

### 5.4 Non-functional

- Tổng <500 LOC code change (CMS ~30, Flutter ~80, backend test ~150, docs ~250).
- Không tăng số DB roundtrip cho mock exam advance.
- Không thay đổi mặc định mock test hiện có (backward compatible).

---

## 6. UX (light)

- Mock test form CMS: tab "Hội thoại AI" hiện màu cyan `#0891B2`, parity layout với 4 tab khác. Picker dropdown chỉ liệt kê interview exercise có `pool='exam'`.
- Flutter mock exam intro: phần "Cấu trúc đề" có thêm row `🎙 Hội thoại AI · 1 phần · 20 điểm` (nếu test có interview section).
- Flutter mock exam runner: khi tới interview section, hiện screen InterviewSessionScreen, nút Back vẫn cho phép thoát (về list section).
- Result screen: section card interview hiển thị transcript + LLM feedback từ submit-interview response.

---

## 7. Acceptance Criteria

### CMS
- [ ] Mở form Mock Test mới, tab "Hội thoại AI" hiện ra với 0 row mặc định.
- [ ] Click "Thêm bài tập" → dropdown chỉ list interview_conversation + interview_choice_explain có pool=exam.
- [ ] Save → reload → tab vẫn hiển thị section đã gán.

### Flutter
- [ ] Mock exam intro screen hiển thị 5 nhóm skill khi test có interview section.
- [ ] Tap section interview → InterviewSessionScreen mở, session chạy được.
- [ ] Session kết thúc → advance về screen list section, status section = completed.
- [ ] Tất cả section xong → result screen hiển thị overall_score bao gồm điểm interview.

### Backend
- [ ] Test mới green.
- [ ] `make backend-test` + `make flutter-{analyze,test}` + `make cms-{lint,build}` xanh.
- [ ] Free-tier user vượt weekly interview cap khi đang làm exam → server trả 429 với `recordErrorRateLimit`, exam pause tại section đó.

### Slice-level
- [ ] CHANGELOG V36 entry + SPEC.md row.
- [ ] Idea/spec/plan/todo docs đủ và sync.
- [ ] Không backfill V21..V35 spec.

---

## 8. Open Questions

1. **Tab nào trong CMS đặt interview?** — đặt cuối cùng sau Viết, hay tách block riêng? Recommend: cuối, sau Viết.
2. **Result card render**: fallback generic card hay viết InterviewResultCard riêng? Recommend MVP fallback; viết custom card khi pilot có user feedback.
3. **Pass threshold + interview**: nếu test pass_threshold=80%, interview chiếm 20/100, học viên fail interview vẫn pass overall nếu các skill khác cao — chấp nhận hay yêu cầu min per-skill? Recommend: chấp nhận MVP, đặt min per-skill khi có data.
4. **Multiple interview section**: cho phép 2+ interview section trong 1 test? Recommend: chấp nhận technically; UI không chặn; weekly cap tự chặn user spam.

---

## 9. References

- AGENTS.md § "Product Scope" — MockTest model.
- `docs/reference/content-and-attempt-model.md` — exercise type catalog.
- `docs/specs/interview-skill.md` — interview MVP spec.
- `docs/specs/interview-first-turn-fix.md` — interview session flow fix.
- `backend/internal/httpapi/server.go:1672-1748` — interview session token + submit handler.
- `flutter_app/lib/features/interview/screens/interview_session_screen.dart` — InterviewSessionScreen widget.
