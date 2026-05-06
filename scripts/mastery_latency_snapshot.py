#!/usr/bin/env python3
"""
Attempt-persist latency snapshot — Phase 2 gate.

Drives N attempts back-to-back against a running backend and measures
how long the persist + mastery-update path takes per attempt. The
mastery hook fires inside Processor.completeAttempt; this is the only
new latency V19 added on the write path, so the snapshot tells us
whether we drifted past the existing SLO.

Reports min / median / p95 / max from POST /v1/attempts → status=completed,
plus a comparison line for "before V19" if --baseline-p95 is provided.

Usage:
  make compose-up
  make seed-modelovy-test-2  # plus a course-pool noi exercise (see CHANGELOG)
  python3 scripts/mastery_latency_snapshot.py --base-url http://localhost:8080 -n 30
  python3 scripts/mastery_latency_snapshot.py --base-url http://localhost:8080 -n 30 --baseline-p95 850

Exit code 0 = snapshot captured; 1 = backend / discovery error or
p95 exceeded the optional baseline by more than the tolerance.
"""

import argparse
import json
import statistics
import sys
import time
import urllib.error
import urllib.request


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


def discover_speaking_exercise(base_url, auth):
    courses_resp = request_json("GET", f"{base_url}/v1/courses", headers=auth)
    courses = courses_resp.get("data") or []
    if not courses:
        raise RuntimeError("no courses; seed first")
    mods_resp = request_json("GET", f"{base_url}/v1/courses/{courses[0]['id']}/modules", headers=auth)
    for mod in mods_resp.get("data") or []:
        ex_resp = request_json("GET",
            f"{base_url}/v1/modules/{mod['id']}/exercises?skill_kind=noi", headers=auth)
        for ex in ex_resp.get("data") or []:
            if ex.get("status") == "published":
                return ex["id"]
    raise RuntimeError("no published noi exercise; create one before benchmarking")


_DUMMY_AUDIO = b"\x00" * 4096  # 4 KB of silence — enough for backend to accept


def _upload_binary(url, method, headers, audio_bytes, auth):
    req = urllib.request.Request(url, data=audio_bytes, method=method)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    # Local upload target points back at the same backend origin; reattach
    # the Authorization header that was implicit on /v1/attempts/* but
    # didn't make it into the upload metadata.
    for k, v in (auth or {}).items():
        req.add_header(k, v)
    with urllib.request.urlopen(req) as resp:
        return resp.status


def time_one_attempt(base_url, auth, exercise_id, *, timeout_s=20.0):
    """Returns total ms from POST /v1/attempts to status terminal.

    Uploads a 4 KB dummy blob so the backend's dev_stub transcribe +
    rule-based scoring path runs to completion. The mastery hook fires
    inside Processor.completeAttempt as part of the persist call we are
    timing — that is exactly the latency this script is here to measure.
    """
    start = time.perf_counter()

    create = request_json("POST", f"{base_url}/v1/attempts",
                          {"exercise_id": exercise_id, "client_platform": "ios", "app_version": "smoke"},
                          headers=auth)
    attempt_id = create["data"]["attempt"]["id"]

    target = request_json(
        "POST", f"{base_url}/v1/attempts/{attempt_id}/upload-url",
        body={
            "mime_type": "audio/m4a",
            "file_size_bytes": len(_DUMMY_AUDIO),
            "duration_ms": 5000,
        },
        headers=auth,
    )
    upload = target["data"]["upload"]
    _upload_binary(upload["url"], upload["method"], upload.get("headers", {}), _DUMMY_AUDIO, auth)

    request_json("POST", f"{base_url}/v1/attempts/{attempt_id}/upload-complete",
                 {
                     "storage_key": upload.get("storage_key", ""),
                     "size_bytes": len(_DUMMY_AUDIO),
                     "duration_ms": 5000,
                     "mime_type": "audio/m4a",
                 },
                 headers=auth)

    deadline = time.perf_counter() + timeout_s
    while True:
        attempt = request_json("GET", f"{base_url}/v1/attempts/{attempt_id}", headers=auth)
        status = (attempt.get("data") or {}).get("status")
        if status in ("completed", "failed"):
            break
        if time.perf_counter() > deadline:
            status = "timeout"
            break
        time.sleep(0.05)
    return (time.perf_counter() - start) * 1000.0, status


def main():
    parser = argparse.ArgumentParser(description="V19 attempt-persist latency snapshot.")
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--email", default="admin@example.com",
                        help="default admin to bypass V17 quota gate; learners cap at 7/day")
    parser.add_argument("--password", default="demo123")
    parser.add_argument("-n", type=int, default=30, help="attempts to drive (default 30)")
    parser.add_argument("--baseline-p95", type=float, default=None,
                        help="if provided, fail when current p95 exceeds baseline by > tolerance")
    parser.add_argument("--tolerance-pct", type=float, default=20.0,
                        help="percent over baseline before failing (default 20%%)")
    args = parser.parse_args()
    base = args.base_url.rstrip("/")

    print(f"=== V19 attempt-persist latency snapshot (n={args.n}) ===", flush=True)

    login = request_json("POST", f"{base}/v1/auth/login",
                         {"email": args.email, "password": args.password})
    token = (login.get("data") or {}).get("access_token")
    if not token:
        print("login failed — no access_token", file=sys.stderr)
        sys.exit(1)
    auth = {"Authorization": f"Bearer {token}"}

    try:
        exercise_id = discover_speaking_exercise(base, auth)
    except Exception as exc:
        print(f"discover error: {exc}", file=sys.stderr)
        sys.exit(1)
    print(f"using exercise_id={exercise_id}", flush=True)

    samples_ms = []
    completed = 0
    failed = 0
    for i in range(args.n):
        try:
            ms, status = time_one_attempt(base, auth, exercise_id)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            print(f"  attempt {i + 1}: HTTP {exc.code} — {body[:200]}", file=sys.stderr)
            continue
        samples_ms.append(ms)
        if status == "completed":
            completed += 1
        else:
            failed += 1
        if (i + 1) % 5 == 0:
            print(f"  progress {i + 1}/{args.n} ({status}, {ms:.0f} ms)", flush=True)

    if not samples_ms:
        print("no samples collected", file=sys.stderr)
        sys.exit(1)

    samples_ms.sort()
    p95 = samples_ms[max(0, int(0.95 * len(samples_ms)) - 1)]
    summary = {
        "n": len(samples_ms),
        "completed": completed,
        "failed": failed,
        "min_ms": min(samples_ms),
        "median_ms": statistics.median(samples_ms),
        "p95_ms": p95,
        "max_ms": max(samples_ms),
        "mean_ms": statistics.mean(samples_ms),
        "stdev_ms": statistics.stdev(samples_ms) if len(samples_ms) > 1 else 0.0,
    }

    print()
    print(json.dumps(summary, indent=2))

    if args.baseline_p95 is not None:
        ceiling = args.baseline_p95 * (1 + args.tolerance_pct / 100.0)
        regressed = p95 > ceiling
        print()
        print(f"baseline p95={args.baseline_p95:.0f} ms  current p95={p95:.0f} ms  "
              f"ceiling={ceiling:.0f} ms  → {'REGRESSED' if regressed else 'within tolerance'}")
        if regressed:
            sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"[HTTP {exc.code}] {exc.url}\n{body}", file=sys.stderr)
        sys.exit(1)
