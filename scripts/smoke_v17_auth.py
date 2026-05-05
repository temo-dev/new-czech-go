#!/usr/bin/env python3
"""
Smoke test: V17 self-serve learner auth surface.

Exercises every endpoint the AppShell relies on:
  signup happy + duplicate + weak password
  login happy + wrong password (no email-existence leak check)
  GET /v1/users/me with token
  PATCH /v1/users/me (display_name + onboarding)
  POST /v1/auth/forgot-password (always 200)
  POST /v1/auth/logout
  GET /v1/users/me after logout (expect 401)

Prereq: backend up with USE_V17_AUTH=true and a clean Postgres slate
        (the script generates a unique email per run, so re-runs are safe).

Usage:
  make smoke-v17-auth
  python3 scripts/smoke_v17_auth.py --base-url http://localhost:8080
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.request


# ANSI shortcuts for CI-friendly output. The existing smoke scripts in
# this repo use the same prefix style so logs blend together.
GREEN = "\033[32m"
RED = "\033[31m"
YELLOW = "\033[33m"
RESET = "\033[0m"

failures: list[str] = []


def ok(label: str) -> None:
    print(f"{GREEN}✓{RESET} {label}")


def fail(label: str, detail: str) -> None:
    failures.append(f"{label}: {detail}")
    print(f"{RED}✗{RESET} {label} — {detail}")


def info(label: str) -> None:
    print(f"{YELLOW}…{RESET} {label}")


def request_json(method: str, url: str, body=None, headers=None):
    """POST/GET/PATCH/DELETE helper. Returns (status_code, parsed_body, raw_text)."""
    all_headers = {"Content-Type": "application/json"}
    if headers:
        all_headers.update(headers)
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=all_headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            text = resp.read().decode("utf-8")
            try:
                return resp.status, json.loads(text) if text else {}, text
            except json.JSONDecodeError:
                return resp.status, {}, text
    except urllib.error.HTTPError as e:
        text = e.read().decode("utf-8") if e.fp else ""
        try:
            return e.code, json.loads(text) if text else {}, text
        except json.JSONDecodeError:
            return e.code, {}, text


def expect(status, want_status, label, body=None):
    if status != want_status:
        fail(label, f"expected HTTP {want_status}, got {status} body={body}")
        return False
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", default="http://localhost:8080")
    args = ap.parse_args()
    base = args.base_url.rstrip("/")

    email = f"smoke-{int(time.time() * 1000)}@example.com"
    pwd = "Strong1Password!"
    weak_pwd = "abc"

    print(f"V17 smoke against {base}")
    print(f"using email: {email}\n")

    # 1. healthz
    info("health check")
    status, body, _ = request_json("GET", f"{base}/healthz")
    if expect(status, 200, "GET /healthz", body):
        ok("backend healthy")

    # 2. signup happy path
    info("signup happy path")
    status, body, _ = request_json("POST", f"{base}/v1/auth/signup", body={
        "email": email,
        "password": pwd,
        "display_name": "Smoke Tester",
    })
    if not expect(status, 200, "POST /v1/auth/signup", body):
        print("\nFATAL: cannot continue without session token")
        sys.exit(1)
    token = body.get("session_token")
    if not token:
        fail("signup", f"missing session_token in body: {body}")
        sys.exit(1)
    if body.get("user", {}).get("email") != email:
        fail("signup", f"response email mismatch: {body.get('user')}")
    elif body.get("user", {}).get("pro_tier") != "free":
        fail("signup", f"new user should be pro_tier=free, got {body['user']}")
    elif body.get("user", {}).get("grace_attempts_left") != 3:
        fail("signup", f"grace_attempts_left should default to 3, got {body['user']}")
    else:
        ok(f"signup returned token + user (id={body['user']['id']})")

    # 3. signup duplicate -> 409 email_taken
    info("signup duplicate email")
    status, body, _ = request_json("POST", f"{base}/v1/auth/signup", body={
        "email": email, "password": pwd, "display_name": "Duplicate",
    })
    if expect(status, 409, "POST /v1/auth/signup (duplicate)", body):
        if body.get("error") == "email_taken":
            ok("duplicate signup -> 409 email_taken")
        else:
            fail("duplicate signup", f"expected error=email_taken, got {body}")

    # 4. signup weak password -> 400 weak_password
    info("signup weak password")
    status, body, _ = request_json("POST", f"{base}/v1/auth/signup", body={
        "email": f"weak-{int(time.time() * 1000)}@example.com",
        "password": weak_pwd,
        "display_name": "Weak",
    })
    if expect(status, 400, "POST /v1/auth/signup (weak pwd)", body):
        if body.get("error") == "weak_password":
            ok("weak password -> 400 weak_password")
        else:
            fail("weak password", f"expected error=weak_password, got {body}")

    # 5. login happy path
    info("login happy path")
    status, body, _ = request_json("POST", f"{base}/v1/auth/login", body={
        "email": email, "password": pwd,
    })
    if expect(status, 200, "POST /v1/auth/login", body):
        login_token = body.get("session_token")
        if login_token and login_token != token:
            ok(f"login returned fresh token (different from signup)")
            # use the freshest token going forward
            token = login_token
        elif login_token == token:
            fail("login", "returned same token as signup (should be fresh issuance)")
        else:
            fail("login", f"missing session_token in body: {body}")

    # 6. login wrong password -> 401 invalid_credentials
    info("login wrong password")
    status, body, _ = request_json("POST", f"{base}/v1/auth/login", body={
        "email": email, "password": "wrong-password",
    })
    if expect(status, 401, "POST /v1/auth/login (wrong pwd)", body):
        if body.get("error") == "invalid_credentials":
            ok("wrong password -> 401 invalid_credentials")
        else:
            fail("wrong password", f"expected invalid_credentials, got {body}")

    # 7. login nonexistent email -> SAME response shape (no leak)
    info("login nonexistent email (no-leak check)")
    status_no_user, body_no_user, _ = request_json("POST", f"{base}/v1/auth/login", body={
        "email": f"nobody-{int(time.time() * 1000)}@example.com",
        "password": "anything-strong-1!",
    })
    if status_no_user == 401 and body_no_user.get("error") == "invalid_credentials":
        ok("nonexistent email -> same 401 invalid_credentials (no leak)")
    else:
        fail("no-leak", f"expected 401 invalid_credentials, got {status_no_user} {body_no_user}")

    # 8. GET /me with valid token
    info("GET /v1/users/me")
    status, body, _ = request_json(
        "GET", f"{base}/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    if expect(status, 200, "GET /v1/users/me", body):
        user = body.get("user", {})
        if user.get("email") == email and "streak" in body and "usage_today" in body:
            ok(f"/me returned user + streak + usage_today")
        else:
            fail("/me", f"unexpected payload: {body}")

    # 9. PATCH /me display_name
    info("PATCH /v1/users/me")
    status, body, _ = request_json(
        "PATCH", f"{base}/v1/users/me",
        body={"display_name": "Updated Name", "onboarding_goal": "a2_pobyt", "onboarding_level": "a1"},
        headers={"Authorization": f"Bearer {token}"},
    )
    if expect(status, 200, "PATCH /v1/users/me", body):
        u = body.get("user", {})
        if u.get("display_name") == "Updated Name" and u.get("onboarding_goal") == "a2_pobyt":
            ok("PATCH /me applied display_name + onboarding_goal")
        else:
            fail("PATCH /me", f"updates not reflected: {u}")

    # 10. role-escalation attempt is silently ignored
    info("PATCH /me cannot escalate role / pro_tier")
    status, body, _ = request_json(
        "PATCH", f"{base}/v1/users/me",
        body={"role": "admin", "pro_tier": "pro", "display_name": "Try Escalate"},
        headers={"Authorization": f"Bearer {token}"},
    )
    if status == 200 and body.get("user", {}).get("role") == "learner":
        ok("role escalation ignored (still learner)")
    else:
        fail("escalation", f"expected role=learner, got {body.get('user')}")

    # 11. forgot-password — ALWAYS 200, no email-existence leak
    info("forgot-password (known email)")
    status, _, _ = request_json("POST", f"{base}/v1/auth/forgot-password", body={"email": email})
    if expect(status, 200, "POST /v1/auth/forgot-password (known)", None):
        ok("forgot-password (known) -> 200")

    info("forgot-password (unknown email)")
    status, _, _ = request_json("POST", f"{base}/v1/auth/forgot-password", body={
        "email": f"nobody-{int(time.time() * 1000)}@example.com",
    })
    if expect(status, 200, "POST /v1/auth/forgot-password (unknown)", None):
        ok("forgot-password (unknown) -> 200 (no leak)")

    # 12. logout -> 204
    info("logout")
    status, _, _ = request_json(
        "POST", f"{base}/v1/auth/logout",
        headers={"Authorization": f"Bearer {token}"},
    )
    if expect(status, 204, "POST /v1/auth/logout", None):
        ok("logout -> 204")

    # 13. /me after logout -> 401
    info("GET /me after logout")
    status, body, _ = request_json(
        "GET", f"{base}/v1/users/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    if expect(status, 401, "GET /v1/users/me (post-logout)", body):
        ok("post-logout -> 401")

    # 14. legacy /v1/auth/signup is 404 when V17 auth is OFF — only
    # meaningful when probing a different deployment.
    # Skipped here because we KNOW the target is V17-on.

    # ── summary ─────────────────────────────────────────────────────────
    print()
    if failures:
        print(f"{RED}FAILED{RESET} ({len(failures)} issue(s)):")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print(f"{GREEN}V17 smoke OK — all checks passed.{RESET}")


if __name__ == "__main__":
    main()
