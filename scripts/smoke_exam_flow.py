#!/usr/bin/env python3
"""
Smoke test: Mock exam session flow.
Tests: login → list mock-tests → create session → submit all sections → complete → verify score.

Section routing by skill_kind:
  noi      → speaking: upload dummy audio, poll until completed
  viet     → writing:  submit-text, poll until completed
  nghe/doc → objective: submit-answers (dummy), sync complete

Prereq: make dev-backend && make seed-modelovy-test-2

Usage:
  make smoke-exam-flow
  python3 scripts/smoke_exam_flow.py --base-url http://localhost:8080
  python3 scripts/smoke_exam_flow.py --base-url http://localhost:8080 --mock-test-id <id>
"""

import argparse
import json
import os
import sys
import tempfile
import time
import urllib.error
import urllib.request


# ---------------------------------------------------------------------------
# HTTP helpers (stdlib only, same pattern as smoke_test_attempt_flow.py)
# ---------------------------------------------------------------------------

def request_json(method, url, body=None, headers=None):
    data = None
    all_headers = {"Content-Type": "application/json"}
    if headers:
        all_headers.update(headers)
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=all_headers, method=method)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def upload_binary(url, file_path, headers=None):
    with open(file_path, "rb") as fh:
        data = fh.read()
    req = urllib.request.Request(url, data=data, headers=dict(headers or {}), method="PUT")
    with urllib.request.urlopen(req) as resp:
        payload = resp.read()
    if not payload:
        return {}
    return json.loads(payload.decode("utf-8"))


def create_dummy_audio_file():
    fd, path = tempfile.mkstemp(prefix="czech-go-smoke-", suffix=".m4a")
    os.close(fd)
    with open(path, "wb") as fh:
        fh.write(b"czech-go-system-smoke-audio")
    return path


def ok(name):
    print(f"[OK] {name}", flush=True)


def fail(name, msg):
    print(f"[FAIL] {name}: {msg}", file=sys.stderr, flush=True)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Per-section submission logic
# ---------------------------------------------------------------------------

DUMMY_PSANI_1_ANSWERS = [
    "Jmenuji se Jana Nováková a bydlím v Praze již dva roky.",
    "Studuji češtinu každý den a jsem velmi ráda za tuto příležitost.",
    "Pracuji jako zdravotní sestra ve velké nemocnici v centru města.",
]
DUMMY_PSANI_2_TEXT = (
    "Dobrý den, píši vám ohledně příštího setkání jazykového kurzu. "
    "Chtěla bych se zeptat na více informací o programu studia. "
    "Studuji češtinu každý den a bydlím v Praze již dva roky. "
    "Pracuji jako zdravotní sestra a ráda se učím nové věci. "
    "Těším se na vaši odpověď. S pozdravem, Jana."
)
DUMMY_ANSWERS = {"1": "A", "2": "B", "3": "C", "4": "A", "5": "B"}


def poll_attempt(base, attempt_id, auth, timeout_sec=30, interval_sec=2):
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        resp = request_json("GET", f"{base}/v1/attempts/{attempt_id}", headers=auth)
        status = (resp.get("data") or {}).get("status", "")
        print(f"  [poll] attempt={attempt_id} status={status}", file=sys.stderr, flush=True)
        if status in {"completed", "failed"}:
            return resp.get("data") or {}
        time.sleep(interval_sec)
    raise TimeoutError(f"attempt {attempt_id} did not finish within {timeout_sec}s")


def submit_speaking_section(base, auth, exercise_id, dummy_audio_path):
    attempt_resp = request_json("POST", f"{base}/v1/attempts", {
        "exercise_id": exercise_id,
        "client_platform": "smoke-test",
        "app_version": "smoke-1",
    }, headers=auth)
    attempt_id = (attempt_resp.get("data") or {}).get("attempt", {}).get("id")
    if not attempt_id:
        fail("speaking attempt create", "no attempt id")

    request_json("POST", f"{base}/v1/attempts/{attempt_id}/recording-started",
                 {"duration_ms": 3000}, headers=auth)

    file_size = os.path.getsize(dummy_audio_path)
    upload_url_resp = request_json("POST", f"{base}/v1/attempts/{attempt_id}/upload-url",
                                   {"mime_type": "audio/m4a", "file_size_bytes": file_size},
                                   headers=auth)
    upload = (upload_url_resp.get("data") or {}).get("upload") or {}
    if not upload.get("url"):
        fail("speaking upload-url", "no upload url")

    upload_binary(upload["url"], dummy_audio_path)

    request_json("POST", f"{base}/v1/attempts/{attempt_id}/upload-complete",
                 {"storage_key": upload.get("storage_key", "")}, headers=auth)

    final = poll_attempt(base, attempt_id, auth, timeout_sec=30)
    if final.get("status") != "completed":
        fail(f"speaking attempt {attempt_id}", f"status={final.get('status')}")
    return attempt_id


def submit_writing_section(base, auth, exercise_id, exercise_type):
    attempt_resp = request_json("POST", f"{base}/v1/attempts", {
        "exercise_id": exercise_id,
        "client_platform": "smoke-test",
        "app_version": "smoke-1",
    }, headers=auth)
    attempt_id = (attempt_resp.get("data") or {}).get("attempt", {}).get("id")
    if not attempt_id:
        fail("writing attempt create", "no attempt id")

    if exercise_type == "psani_1_formular":
        body = {"answers": DUMMY_PSANI_1_ANSWERS}
    else:
        body = {"text": DUMMY_PSANI_2_TEXT}

    request_json("POST", f"{base}/v1/attempts/{attempt_id}/submit-text", body, headers=auth)

    final = poll_attempt(base, attempt_id, auth, timeout_sec=60)
    if final.get("status") != "completed":
        fail(f"writing attempt {attempt_id}", f"status={final.get('status')}")
    return attempt_id


def submit_objective_section(base, auth, exercise_id):
    attempt_resp = request_json("POST", f"{base}/v1/attempts", {
        "exercise_id": exercise_id,
        "client_platform": "smoke-test",
        "app_version": "smoke-1",
    }, headers=auth)
    attempt_id = (attempt_resp.get("data") or {}).get("attempt", {}).get("id")
    if not attempt_id:
        fail("objective attempt create", "no attempt id")

    resp = request_json("POST", f"{base}/v1/attempts/{attempt_id}/submit-answers",
                        {"answers": DUMMY_ANSWERS}, headers=auth)
    status = (resp.get("data") or {}).get("status", "")
    if status != "completed":
        fail(f"objective attempt {attempt_id}", f"expected completed, got {status}")
    return attempt_id


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Smoke test mock exam session flow.")
    parser.add_argument("--base-url", required=True, help="API base URL, e.g. http://localhost:8080")
    parser.add_argument("--email", default="learner@example.com")
    parser.add_argument("--password", default="demo123")
    parser.add_argument("--mock-test-id", default="", help="Mock test ID. If omitted, uses first published test.")
    parser.add_argument("--audio-file", default="", help="Real audio file for speaking sections. Required when backend uses S3 upload.")
    args = parser.parse_args()
    base = args.base_url.rstrip("/")

    print("=== Smoke: Exam Flow ===", flush=True)

    # 1. Login
    login_resp = request_json("POST", f"{base}/v1/auth/login", {"email": args.email, "password": args.password})
    token = (login_resp.get("data") or {}).get("access_token")
    if not token:
        fail("login", "no access_token")
    auth = {"Authorization": f"Bearer {token}"}
    ok("login")

    # 2. Get mock test
    mock_test_id = args.mock_test_id
    if not mock_test_id:
        resp = request_json("GET", f"{base}/v1/mock-tests", headers=auth)
        mock_tests = resp.get("data") or []
        if not mock_tests:
            fail("list mock-tests", "empty — run `make seed-modelovy-test-2` first")
        mock_test_id = mock_tests[0]["id"]
        ok(f"list mock-tests — using '{mock_tests[0].get('title')}'")
    else:
        ok(f"using mock-test-id={mock_test_id}")

    # 3. Create mock exam session
    session_resp = request_json("POST", f"{base}/v1/mock-exams", {"mock_test_id": mock_test_id}, headers=auth)
    session = session_resp.get("data") or {}
    session_id = session.get("id")
    if not session_id:
        fail("create mock exam", "no session id")
    sections = session.get("sections") or []
    if not sections:
        fail("create mock exam", "no sections")
    ok(f"create mock exam session — {len(sections)} section(s)")

    # 4. Prepare audio for speaking sections
    dummy_audio = args.audio_file if args.audio_file else create_dummy_audio_file()
    created_dummy = not args.audio_file

    # 5. Submit each section
    for i, section in enumerate(sections):
        seq = section.get("sequence_no", i + 1)
        exercise_id = section.get("exercise_id", "")
        exercise_type = section.get("exercise_type", "")

        print(f"  [section {seq}] type={exercise_type}", flush=True)

        if exercise_type.startswith("uloha_"):
            attempt_id = submit_speaking_section(base, auth, exercise_id, dummy_audio)
        elif exercise_type.startswith("psani_"):
            attempt_id = submit_writing_section(base, auth, exercise_id, exercise_type)
        else:
            attempt_id = submit_objective_section(base, auth, exercise_id)

        # Advance mock exam with this attempt
        request_json("POST", f"{base}/v1/mock-exams/{session_id}/advance",
                     {"attempt_id": attempt_id}, headers=auth)
        ok(f"section {seq} ({exercise_type})")

    # 6. Complete mock exam
    complete_resp = request_json("POST", f"{base}/v1/mock-exams/{session_id}/complete", {}, headers=auth)
    completed = complete_resp.get("data") or {}
    if completed.get("status") != "completed":
        fail("complete mock exam", f"status={completed.get('status')}")
    ok(f"complete — overall_score={completed.get('overall_score')} passed={completed.get('passed')}")

    # Cleanup dummy audio (only if we created it)
    if created_dummy:
        try:
            os.unlink(dummy_audio)
        except OSError:
            pass

    print("=== PASS ===", flush=True)


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"[HTTP {exc.code}] {exc.url}\n{body}", file=sys.stderr)
        sys.exit(1)
    except TimeoutError as exc:
        print(f"[TIMEOUT] {exc}", file=sys.stderr)
        sys.exit(1)
