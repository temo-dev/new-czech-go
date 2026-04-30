#!/usr/bin/env python3
"""
Smoke test: Course browsing flow.
Tests: login → list courses → course detail → module skills → skill exercises → exercise detail.

Prereq: make dev-backend && make seed-modelovy-test-2

Usage:
  make smoke-course-flow
  python3 scripts/smoke_course_flow.py --base-url http://localhost:8080
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
        return json.loads(resp.read().decode("utf-8"))


def ok(name):
    print(f"[OK] {name}", flush=True)


def fail(name, msg):
    print(f"[FAIL] {name}: {msg}", file=sys.stderr, flush=True)
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Smoke test course browsing flow.")
    parser.add_argument("--base-url", required=True, help="API base URL, e.g. http://localhost:8080")
    parser.add_argument("--email", default="learner@example.com")
    parser.add_argument("--password", default="demo123")
    args = parser.parse_args()
    base = args.base_url.rstrip("/")

    print("=== Smoke: Course Flow ===", flush=True)

    # 1. Login
    login_resp = request_json("POST", f"{base}/v1/auth/login", {"email": args.email, "password": args.password})
    token = (login_resp.get("data") or {}).get("access_token")
    if not token:
        fail("login", "no access_token in response")
    auth = {"Authorization": f"Bearer {token}"}
    ok("login")

    # 2. List courses
    resp = request_json("GET", f"{base}/v1/courses", headers=auth)
    courses = resp.get("data") or []
    if not courses:
        fail("list courses", "empty — run `make seed-modelovy-test-2` first")
    course = courses[0]
    ok(f"list courses ({len(courses)} found, using '{course.get('title')}')")

    # 3. Course modules
    resp = request_json("GET", f"{base}/v1/courses/{course['id']}/modules", headers=auth)
    modules = resp.get("data") or []
    if not modules:
        fail("course modules", "no modules — run `make seed-modelovy-test-2` first")
    module = modules[0]
    ok(f"course modules — {len(modules)} module(s)")

    # 4. Module → skills
    resp = request_json("GET", f"{base}/v1/modules/{module['id']}/skills", headers=auth)
    skills = resp.get("data") or []
    if not skills:
        fail("module skills", "no skills in response")
    skill = skills[0]
    ok(f"module skills — {len(skills)} skill(s), using skill_kind={skill.get('skill_kind')}")

    # 5. Skill → exercises
    resp = request_json("GET", f"{base}/v1/skills/{skill['id']}/exercises", headers=auth)
    exercises = resp.get("data") or []
    if not exercises:
        fail("skill exercises", "no exercises in response")
    exercise = exercises[0]
    ok(f"skill exercises — {len(exercises)} exercise(s)")

    # 6. Exercise detail
    resp = request_json("GET", f"{base}/v1/exercises/{exercise['id']}", headers=auth)
    ex_detail = resp.get("data") or {}
    if not ex_detail.get("exercise_type"):
        fail("exercise detail", "missing exercise_type")
    ok(f"exercise detail — type={ex_detail['exercise_type']} title='{ex_detail.get('title')}'")

    print("=== PASS ===", flush=True)


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        print(f"[HTTP {exc.code}] {exc.url}\n{body}", file=sys.stderr)
        sys.exit(1)
