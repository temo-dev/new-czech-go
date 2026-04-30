# E2E Smoke Test System

## Problem Statement

How might we build an automated smoke test suite that an AI Agent can run via `make smoke-*` to verify the exam flow and course flow against a real running backend?

## Recommended Direction

Thêm 2 Python scripts mới (`smoke_course_flow.py`, `smoke_exam_flow.py`) + Makefile targets tương ứng. Cùng pattern với `smoke_test_attempt_flow.py` hiện có: pure stdlib Python, `--base-url` flag, exit code 0/1 để AI Agent đọc output.

**Lý do không mở rộng script cũ:** script cũ đã ổn định, test speaking flow. Tách riêng giúp AI Agent chạy từng flow độc lập mà không risk break existing smoke test.

**Lý do không dùng Go httptest:** cần test DB, phức tạp hơn. Python scripts dễ extend hơn cho AI Agent (readable output, no compile step).

## Key Assumptions to Validate

- [ ] Backend đang chạy tại `SMOKE_BASE_URL` (mặc định `http://localhost:8080`)
- [ ] Có ít nhất 1 course + module + exercise published trong DB khi chạy test
- [ ] Mock test đã được seed với `make seed-modelovy-test-2` trước khi chạy exam smoke
- [ ] Writing/listening/reading exercises không cần audio file (submit-text / submit-answers)

## MVP Scope

### `scripts/smoke_course_flow.py`
```
1. POST /v1/learners/login → bearer token
2. GET /v1/courses → assert non-empty list
3. GET /v1/courses/:id → assert modules present
4. GET /v1/modules/:id/skills → assert skills present
5. GET /v1/skills/:id/exercises → assert exercises present
6. GET /v1/exercises/:id → assert exercise detail fields non-empty
```

### `scripts/smoke_exam_flow.py`
```
1. POST /v1/learners/login → bearer token
2. GET /v1/mock-tests → pick first published mock test
3. POST /v1/mock-exams (mock_test_id) → session created
4. For each section (speaking skip / writing / listening / reading):
   - POST /v1/attempts → attempt_id
   - Submit answers (submit-text or submit-answers depending on type)
   - Poll until completed
5. POST /v1/mock-exams/:id/complete → assert score computed, passed field present
```

### Makefile targets mới
```makefile
smoke-course-flow:
    python3 scripts/smoke_course_flow.py --base-url $(SMOKE_BASE_URL)

smoke-exam-flow:
    python3 scripts/smoke_exam_flow.py --base-url $(SMOKE_BASE_URL)

smoke-all: smoke-attempt-flow smoke-course-flow smoke-exam-flow
```

## Not Doing (and Why)

- **Flutter UI smoke test** — cần physical device/simulator, không thể AI Agent chạy headless
- **CMS Playwright tests** — CMS là admin-only thin desk, ít regression risk hơn learner flows
- **Full exam session (písemná + ústní combined)** — 2-part flow phức tạp, defer sau khi 2 flows cơ bản ổn định
- **Speaking section trong exam smoke** — requires real audio file + AWS Transcribe, giống constraint của script cũ; skip section, log "SKIP speaking — needs audio file"

## Open Questions

- Speaking section trong mock exam smoke: skip hoàn toàn hay dùng dummy audio như script cũ?
- `seed-modelovy-test-2` có đủ data cho cả course flow lẫn exam flow không, hay cần seed riêng?
- `SMOKE_BASE_URL` default: `http://localhost:8080` hay để user luôn phải truyền?
