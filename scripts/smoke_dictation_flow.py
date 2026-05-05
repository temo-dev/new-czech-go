#!/usr/bin/env python3
"""V18 smoke test: end-to-end dictation attempt flow.

Steps:
  1. login as admin → create a published psani_3_dictation exercise
  2. login as learner → create attempt → submit-text with sentences
  3. poll attempt until completed → assert dictation_result is present
     with the expected overall_score and per-sentence accuracies
  4. cleanup: delete the exercise

Run against a local backend by default. Pass --base-url for cloud.
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request


def request_json(method, url, body=None, headers=None):
    payload = None
    all_headers = {"Content-Type": "application/json"}
    if headers:
        all_headers.update(headers)
    if body is not None:
        payload = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=payload, headers=all_headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            data = resp.read()
    except urllib.error.HTTPError as e:
        body_str = e.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"{method} {url} → HTTP {e.code}: {body_str}") from e
    if not data:
        return {}
    return json.loads(data.decode("utf-8"))


def login(base_url, email, password):
    resp = request_json(
        "POST",
        f"{base_url}/v1/auth/login",
        body={"email": email, "password": password},
    )
    token = resp.get("data", {}).get("access_token")
    if not token:
        raise RuntimeError(f"login response missing access_token: {resp}")
    return token


def create_dictation_exercise(base_url, admin_headers, module_id):
    body = {
        "module_id": module_id,
        "skill_kind": "viet",
        "exercise_type": "psani_3_dictation",
        "title": "Smoke — Trong quán cafe",
        "short_instruction": "Nghe và viết lại từng câu.",
        "learner_instruction": "",
        "estimated_duration_sec": 600,
        "sample_answer_enabled": False,
        "status": "published",
        "pool": "course",
        "detail": {
            "topic": "Smoke",
            "context_image_asset_id": "",
            "sentences": [
                {"idx": 0, "text": "Pavel jde do kavárny.", "audio_asset_id": ""},
                {"idx": 1, "text": "Chce si dát čaj.", "audio_asset_id": ""},
                {"idx": 2, "text": "Děkuji.", "audio_asset_id": ""},
            ],
            "max_replays_per_sentence": 3,
            "voice_id": "",
            "max_points": 10,
            "pass_threshold_percent": 60,
        },
    }
    resp = request_json("POST", f"{base_url}/v1/admin/exercises", body=body, headers=admin_headers)
    ex = resp.get("data") or {}
    if not ex.get("id"):
        raise RuntimeError(f"admin create exercise response: {resp}")
    return ex["id"]


def delete_exercise(base_url, admin_headers, exercise_id):
    req = urllib.request.Request(
        f"{base_url}/v1/admin/exercises/{exercise_id}",
        method="DELETE",
        headers=admin_headers,
    )
    try:
        with urllib.request.urlopen(req):
            pass
    except urllib.error.HTTPError:
        # 404 / 405 acceptable on cleanup; do not raise
        pass


def discover_module_id(base_url, learner_headers):
    """Pick the first viet-skill module to attach the smoke exercise to."""
    resp = request_json("GET", f"{base_url}/v1/modules", headers=learner_headers)
    modules = resp.get("data") or []
    if not modules:
        raise RuntimeError("no modules in repo — seed required")
    return modules[0]["id"]


def poll_attempt(base_url, attempt_id, learner_headers, timeout_sec, interval_sec):
    deadline = time.time() + timeout_sec
    last_status = None
    while time.time() < deadline:
        resp = request_json(
            "GET", f"{base_url}/v1/attempts/{attempt_id}", headers=learner_headers
        )
        data = resp.get("data") or {}
        status = data.get("status", "")
        if status != last_status:
            print(f"[poll] attempt={attempt_id} status={status}", file=sys.stderr, flush=True)
            last_status = status
        if status in ("completed", "failed"):
            return data
        time.sleep(interval_sec)
    raise TimeoutError(f"attempt {attempt_id} did not finish within {timeout_sec}s")


def main():
    parser = argparse.ArgumentParser(description="V18 dictation smoke test")
    parser.add_argument("--base-url", default="http://127.0.0.1:8080")
    parser.add_argument("--admin-email", default=os.getenv("ADMIN_EMAIL", "admin@example.com"))
    parser.add_argument("--admin-password", default=os.getenv("ADMIN_PASSWORD", "demo123"))
    parser.add_argument("--learner-email", default="learner@example.com")
    parser.add_argument("--learner-password", default="demo123")
    parser.add_argument("--timeout-sec", type=int, default=20)
    parser.add_argument("--poll-interval-sec", type=float, default=0.5)
    args = parser.parse_args()

    base_url = args.base_url.rstrip("/")

    admin_token = login(base_url, args.admin_email, args.admin_password)
    learner_token = login(base_url, args.learner_email, args.learner_password)
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    learner_headers = {"Authorization": f"Bearer {learner_token}"}

    module_id = discover_module_id(base_url, learner_headers)
    exercise_id = create_dictation_exercise(base_url, admin_headers, module_id)
    print(f"[smoke] created exercise_id={exercise_id}", file=sys.stderr, flush=True)

    try:
        attempt_resp = request_json(
            "POST",
            f"{base_url}/v1/attempts",
            body={
                "exercise_id": exercise_id,
                "client_platform": "smoke-test",
                "app_version": "smoke-v18",
                "locale": "vi",
            },
            headers=learner_headers,
        )
        attempt_id = attempt_resp["data"]["attempt"]["id"]
        print(f"[smoke] attempt_id={attempt_id}", file=sys.stderr, flush=True)

        # Submit perfect transcription — score should be 10/10.
        request_json(
            "POST",
            f"{base_url}/v1/attempts/{attempt_id}/submit-text",
            body={
                "sentences": [
                    {"idx": 0, "text": "Pavel jde do kavárny.", "replay_count": 1},
                    {"idx": 1, "text": "Chce si dát čaj.", "replay_count": 0},
                    {"idx": 2, "text": "Děkuji.", "replay_count": 2},
                ]
            },
            headers=learner_headers,
        )

        attempt = poll_attempt(
            base_url, attempt_id, learner_headers,
            timeout_sec=args.timeout_sec,
            interval_sec=args.poll_interval_sec,
        )

        if attempt["status"] != "completed":
            raise RuntimeError(f"attempt did not complete: {attempt}")

        feedback = attempt.get("feedback") or {}
        dict_result = feedback.get("dictation_result")
        if not dict_result:
            raise RuntimeError(f"feedback missing dictation_result: {feedback}")

        overall = dict_result.get("overall_score")
        passed = dict_result.get("passed")
        sentences = dict_result.get("sentences") or []
        if overall != 10:
            raise RuntimeError(f"expected overall_score=10, got {overall}")
        if not passed:
            raise RuntimeError("expected passed=true on perfect submission")
        if len(sentences) != 3:
            raise RuntimeError(f"expected 3 sentence rows, got {len(sentences)}")
        for i, s in enumerate(sentences):
            if abs(float(s["accuracy"]) - 1.0) > 1e-6:
                raise RuntimeError(f"sentence[{i}] accuracy != 1.0: {s}")

        print("[smoke] PASS — dictation flow end-to-end", flush=True)
    finally:
        delete_exercise(base_url, admin_headers, exercise_id)


if __name__ == "__main__":
    main()
