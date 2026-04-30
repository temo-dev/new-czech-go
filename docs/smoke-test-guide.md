# Smoke Test Guide

End-to-end API smoke tests cho AI Agents và developers. Tất cả scripts dùng Python stdlib, exit code 0 = PASS, 1 = FAIL.

## Tổng quan

| Make target | Script | Covers |
|---|---|---|
| `smoke-attempt-flow` | `scripts/smoke_test_attempt_flow.py` | Speaking attempt: login → create → upload audio → poll → completed |
| `smoke-course-flow` | `scripts/smoke_course_flow.py` | Course browsing: login → courses → modules → skills → exercises |
| `smoke-exam-flow` | `scripts/smoke_exam_flow.py` | Mock exam session: create → submit all sections → complete → score |
| `smoke-all` | (chạy 3 cái trên theo thứ tự) | Full regression |

## Prereq

```bash
# 1. Backend chạy
make dev-backend

# 2. Seed data (chỉ cần 1 lần — data persist trong Postgres)
make seed-modelovy-test-2
```

Seed tạo ra:
- 1 Course với 4 Modules (Mluvení / Psaní / Poslech / Čtení)
- Exercises pool=course cho mỗi skill
- Exercises pool=exam cho MockTest sections
- 2 MockTests: `speaking` (Mluvení, 40đ) và `pisemna` (Čtení+Psaní+Poslech, 70đ)

## Chạy

### Local mode (backend không dùng S3)

```bash
make smoke-attempt-flow
make smoke-course-flow
make smoke-exam-flow
make smoke-all
```

### Cloud mode (backend dùng S3 — yêu cầu real audio file)

```bash
AUDIO=/path/to/sample.m4a

make smoke-attempt-flow SMOKE_ATTEMPT_ARGS="--audio-file $AUDIO"
make smoke-course-flow                           # không cần audio
make smoke-exam-flow SMOKE_AUDIO_FILE=$AUDIO
make smoke-all SMOKE_ATTEMPT_ARGS="--audio-file $AUDIO" SMOKE_AUDIO_FILE=$AUDIO
```

### Chạy với URL khác (staging / EC2)

```bash
make smoke-all \
  SMOKE_BASE_URL=https://apicz.hadoo.eu \
  SMOKE_ATTEMPT_ARGS="--audio-file $AUDIO" \
  SMOKE_AUDIO_FILE=$AUDIO
```

## Biến môi trường Makefile

| Biến | Mặc định | Mô tả |
|---|---|---|
| `SMOKE_BASE_URL` | `http://localhost:8080` | API base URL |
| `SMOKE_ATTEMPT_ARGS` | (trống) | Args thêm cho `smoke-attempt-flow` |
| `SMOKE_AUDIO_FILE` | (trống) | Path audio file cho `smoke-exam-flow` speaking sections |

## Khi nào chạy cái gì

| Thay đổi | Smoke test cần chạy |
|---|---|
| Sửa speaking/attempt/scoring logic | `smoke-attempt-flow` |
| Sửa course/module/skill/exercise API | `smoke-course-flow` |
| Sửa mock exam, objective scoring, writing scoring | `smoke-exam-flow` |
| Trước khi merge PR lớn | `smoke-all` |
| Sau khi deploy production | `smoke-all` với `SMOKE_BASE_URL=https://apicz.hadoo.eu` |

## Routing sections trong exam flow

`smoke_exam_flow.py` route theo `exercise_type` của từng section:

| exercise_type prefix | Submission method |
|---|---|
| `uloha_*` | Speaking: upload audio → poll until completed |
| `psani_*` | Writing: `POST submit-text` → poll until completed |
| `cteni_*`, `poslech_*`, ... | Objective: `POST submit-answers` → sync complete |

## Troubleshooting

### `Exercise not found` (404)
Seed chưa chạy hoặc backend dùng DB khác.
```bash
make seed-modelovy-test-2
```

### `upload target points to cloud storage`
Backend dùng S3. Cần real audio file:
```bash
make smoke-attempt-flow SMOKE_ATTEMPT_ARGS="--audio-file /path/to/sample.m4a"
```

### `answer N has X words, minimum is 10` (400)
Dummy text trong script quá ngắn. Kiểm tra `DUMMY_PSANI_1_ANSWERS` trong `smoke_exam_flow.py` — mỗi answer phải ≥10 từ.

### `Scoring Failed` (500) trên psani section
Script đang gọi `submit-answers` cho writing exercise. Kiểm tra routing — `psani_*` phải dùng `submit-text`.

### `attempt did not finish within Xs` (timeout)
- Local mode: tăng `--timeout-sec` hoặc kiểm tra backend log
- Cloud mode: AWS Transcribe chậm, tăng timeout: `SMOKE_ATTEMPT_ARGS="--audio-file $AUDIO --timeout-sec 300"`

## API notes (quan trọng cho Agents)

- `GET /v1/courses/:id` trả về **chỉ course object** — **không** embed modules.
- Để lấy modules: `GET /v1/courses/:id/modules`
- `GET /v1/modules/:id/skills` trả về skills của module
- `GET /v1/skills/:id/exercises` trả về exercises của skill
- `MockExamSessionItem.skill_kind` có thể trống — luôn route theo `exercise_type`
- Objective scoring (`submit-answers`) là **sync** — response trả về `status=completed` ngay
- Writing scoring (`submit-text`) là **async** — cần poll cho đến khi `status=completed`
- Speaking scoring là **async** — cần poll, cloud mode mất 30-180s tùy AWS Transcribe

## Files

```
scripts/
  smoke_test_attempt_flow.py   # speaking attempt flow
  smoke_course_flow.py         # course browsing flow
  smoke_exam_flow.py           # mock exam session flow
  seed-modelovy-test-2.py      # seed data cho tất cả smoke tests
docs/
  smoke-test-guide.md          # file này
```
