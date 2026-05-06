#!/usr/bin/env python3
"""
Smoke test: V19 / V20 progress endpoint.

Verifies GET /v1/users/me/progress against the contract documented in
`docs/specs/skill-mastery-progress.md`:

  - 401 without a bearer token
  - 200 with bearer; response carries the V20 wire shape
    (overall_progress, overall_band, skills[], bands{needs_work,solid,ready},
    weights{noi,viet,...})
  - bands thresholds are monotonically increasing
  - per-skill mastery falls in [0, 1]; band string matches the cfg
    band the value bucketises into
  - second call is idempotent (same shape, no spurious mutations)
  - if `--require-rows` is passed, asserts at least one persisted skill
    row (caller is expected to have run an attempt beforehand)

Prereq: backend up + at least one user able to log in.

  make compose-up
  make smoke-progress-flow
  python3 scripts/smoke_progress_flow.py --base-url http://localhost:8080
"""

import argparse
import json
import sys
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
        return resp.status, json.loads(resp.read().decode("utf-8"))


def ok(name):
    print(f"[OK] {name}", flush=True)


def fail(name, msg):
    print(f"[FAIL] {name}: {msg}", file=sys.stderr, flush=True)
    sys.exit(1)


def expect_band(mastery, bands):
    """Mirror the backend MasteryConfig.BandFromMastery rule."""
    if mastery < bands["needs_work"]:
        return "needs_work"
    if mastery < bands["solid"]:
        return "learning"
    if mastery < bands["ready"]:
        return "solid"
    return "ready"


def main():
    parser = argparse.ArgumentParser(description="Smoke test V19/V20 progress endpoint.")
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--email", default="learner@example.com")
    parser.add_argument("--password", default="demo123")
    parser.add_argument(
        "--require-rows",
        action="store_true",
        help="Assert at least one populated skill row (run an attempt first).",
    )
    args = parser.parse_args()
    base = args.base_url.rstrip("/")

    print("=== Smoke: Progress Flow (V19/V20) ===", flush=True)

    # 1. Unauthenticated request must be rejected.
    try:
        request_json("GET", f"{base}/v1/users/me/progress")
        fail("auth gate", "endpoint returned 200 without bearer token")
    except urllib.error.HTTPError as exc:
        if exc.code != 401:
            fail("auth gate", f"expected 401, got {exc.code}")
        ok("auth gate — 401 without bearer")

    # 2. Login.
    _, login_resp = request_json(
        "POST", f"{base}/v1/auth/login", {"email": args.email, "password": args.password}
    )
    token = (login_resp.get("data") or {}).get("access_token")
    if not token:
        fail("login", "no access_token in response")
    auth = {"Authorization": f"Bearer {token}"}
    ok("login")

    # 3. Authenticated GET.
    status, resp = request_json("GET", f"{base}/v1/users/me/progress", headers=auth)
    if status != 200:
        fail("authenticated GET", f"expected 200, got {status}")
    progress = resp.get("data") or {}

    # 4. Top-level shape.
    for key in ("overall_progress", "overall_band", "skills", "bands", "weights"):
        if key not in progress:
            fail("wire shape", f"missing top-level key '{key}'")
    ok("wire shape — top-level keys present")

    # 5. Overall progress in [0, 1].
    overall = float(progress["overall_progress"])
    if not (0.0 <= overall <= 1.0):
        fail("overall_progress range", f"{overall} not in [0, 1]")
    ok(f"overall_progress in range — value={overall:.3f}")

    # 6. Bands monotonically increasing.
    bands = progress["bands"]
    for k in ("needs_work", "solid", "ready"):
        if k not in bands:
            fail("bands shape", f"missing bands['{k}']")
    if not (bands["needs_work"] < bands["solid"] < bands["ready"]):
        fail(
            "bands monotonic",
            f"expected needs_work < solid < ready, got {bands}",
        )
    ok(f"bands monotonic — {bands}")

    # 7. Overall band classification matches bands config.
    expected_overall_band = expect_band(overall, bands)
    if progress["overall_band"] != expected_overall_band:
        fail(
            "overall_band classification",
            f"mastery={overall} bands={bands} → expected '{expected_overall_band}', "
            f"got '{progress['overall_band']}'",
        )
    ok(f"overall_band classified — '{progress['overall_band']}'")

    # 8. Weights present + non-negative.
    weights = progress["weights"]
    if not isinstance(weights, dict):
        fail("weights shape", f"expected object, got {type(weights).__name__}")
    for k, v in weights.items():
        if not isinstance(v, int) or v < 0:
            fail("weights values", f"weights['{k}']={v} must be a non-negative int")
    ok(f"weights present — {len(weights)} entries")

    # 9. Per-skill validation.
    skills = progress["skills"] or []
    for skill in skills:
        for k in ("skill_kind", "mastery", "band", "attempts_count", "modules"):
            if k not in skill:
                fail("skill shape", f"skill missing '{k}': {skill}")
        m = float(skill["mastery"])
        if not (0.0 <= m <= 1.0):
            fail("skill mastery range", f"skill={skill['skill_kind']} mastery={m}")
        if skill["band"] != expect_band(m, bands):
            fail(
                "skill band classification",
                f"skill={skill['skill_kind']} mastery={m} band='{skill['band']}'",
            )
        if int(skill["attempts_count"]) < 0:
            fail("attempts_count", f"negative on skill={skill['skill_kind']}")
        for module in skill["modules"]:
            for k in ("module_id", "mastery", "band", "attempts_count"):
                if k not in module:
                    fail("module shape", f"module missing '{k}': {module}")
            mm = float(module["mastery"])
            if not (0.0 <= mm <= 1.0):
                fail(
                    "module mastery range",
                    f"skill={skill['skill_kind']} module={module['module_id']} mastery={mm}",
                )
            if module["band"] != expect_band(mm, bands):
                fail(
                    "module band classification",
                    f"skill={skill['skill_kind']} module={module['module_id']} "
                    f"mastery={mm} band='{module['band']}'",
                )
    ok(f"skills validated — {len(skills)} skill(s)")

    if args.require_rows and not skills:
        fail("require-rows", "no persisted skill rows; run an attempt first")

    # 10. Idempotency — second call returns the same shape.
    _, resp2 = request_json("GET", f"{base}/v1/users/me/progress", headers=auth)
    progress2 = resp2.get("data") or {}
    if progress2.get("overall_progress") != progress["overall_progress"]:
        fail("idempotent overall", "overall_progress changed between calls")
    if len(progress2.get("skills") or []) != len(skills):
        fail("idempotent skills", "skill count changed between calls")
    ok("idempotent — second call matches first")

    # 11. Summary.
    summary = {
        "overall_progress": overall,
        "overall_band": progress["overall_band"],
        "skill_count": len(skills),
        "bands": bands,
        "weights": weights,
        "skills": [
            {
                "skill_kind": s["skill_kind"],
                "mastery": s["mastery"],
                "band": s["band"],
                "attempts": s["attempts_count"],
                "modules": len(s.get("modules") or []),
            }
            for s in skills
        ],
    }
    print(json.dumps(summary, indent=2, ensure_ascii=False), flush=True)
    print("=== PASS ===", flush=True)


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"[HTTP {exc.code}] {exc.url}\n{body}", file=sys.stderr)
        sys.exit(1)
