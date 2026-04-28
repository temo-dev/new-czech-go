#!/usr/bin/env python3
"""Clean up local dev DB: remove duplicates, orphans, and manual test data.
Keeps the properly seeded course-9b57edec with 4 modules/skills/16 exercises.
Patches seeded exercises with correct skill_id assignments.
"""

import json
import sys
import urllib.request
import urllib.error

BASE = "http://localhost:8080"
TOKEN = "dev-admin-token"


def api(method, path, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  ERROR {method} {path}: {e.code} {body[:120]}")
        return None


def delete(path):
    r = api("DELETE", path)
    ok = r is not None and ("data" in r or r.get("data", {}).get("deleted"))
    print(f"  {'✓' if ok else '✗'} DELETE {path}")
    return ok


def patch(path, body):
    r = api("PATCH", path, body)
    ok = r is not None and "data" in r
    print(f"  {'✓' if ok else '✗'} PATCH  {path} {body}")
    return ok


# ── Canonical seeded IDs to KEEP ─────────────────────────────────────────────
KEEP_COURSE = "course-9b57edec-9c8f-4b19-be8b-764a79818709"

KEEP_MODULES = {
    "module-651cd7dd-5cec-49d3-b686-1e593ed584d4",  # Mluvení — Nói
    "module-14762c14-102c-42fa-9636-b76a095ad4e1",  # Psaní — Viết
    "module-0a3a0609-85d9-4855-affc-bdbc201bf09b",  # Poslech — Nghe
    "module-0c47253b-7291-4bb7-ba97-80d7fd4d6b3c",  # Čtení — Đọc
}

KEEP_SKILLS = {
    "skill-0fc5e7d7-0dbd-403e-932f-8fb0e02f8ebc",  # Nói (Mluvení)
    "skill-6f78fdb6-e1a4-4a8f-9490-4c8a44be197b",  # Viết (Psaní)
    "skill-b42c6ae4-8120-4229-b21c-c80f12f35e5f",  # Nghe (Poslech)
    "skill-d85e3b31-3ead-4c46-8407-d3a47c4caf2b",  # Đọc (Čtení)
}

# Seeded exercise IDs → target skill_id
SEED_EXERCISES = {
    "exercise-7f071f2d-50a4-4eee-9f97-35dce31473a0": "skill-0fc5e7d7-0dbd-403e-932f-8fb0e02f8ebc",
    "exercise-e1ba3224-04ea-44e1-a49d-a3d7dfb3e871": "skill-0fc5e7d7-0dbd-403e-932f-8fb0e02f8ebc",
    "exercise-b6066f70-e47b-4889-9392-02a162e279a1": "skill-0fc5e7d7-0dbd-403e-932f-8fb0e02f8ebc",
    "exercise-f28e06a1-b512-4cdb-b1cd-6495509a0b5b": "skill-0fc5e7d7-0dbd-403e-932f-8fb0e02f8ebc",
    "exercise-b1349581-746c-47be-8e10-5693a8a2546d": "skill-6f78fdb6-e1a4-4a8f-9490-4c8a44be197b",
    "exercise-c1f3744c-8754-4747-9fa6-eb6d9e45209a": "skill-6f78fdb6-e1a4-4a8f-9490-4c8a44be197b",
    "exercise-48214e34-4bc2-4f22-af5f-40062b688ed2": "skill-b42c6ae4-8120-4229-b21c-c80f12f35e5f",
    "exercise-d7105cfa-4980-4d01-a340-fac0b98ff699": "skill-b42c6ae4-8120-4229-b21c-c80f12f35e5f",
    "exercise-8b0f2dbd-ea74-4436-b879-e0892464cfeb": "skill-b42c6ae4-8120-4229-b21c-c80f12f35e5f",
    "exercise-b7db53df-112c-4ab9-ad54-607959eb9507": "skill-b42c6ae4-8120-4229-b21c-c80f12f35e5f",
    "exercise-2a0c02c1-acda-4e4c-bb7e-bc9c887262d2": "skill-b42c6ae4-8120-4229-b21c-c80f12f35e5f",
    "exercise-6670d188-fde9-4c9d-9dab-b70e54b78321": "skill-d85e3b31-3ead-4c46-8407-d3a47c4caf2b",
    "exercise-9eb3c329-18d6-48af-ab28-e52b40567ac4": "skill-d85e3b31-3ead-4c46-8407-d3a47c4caf2b",
    "exercise-e7f62a9d-558e-4f93-9584-3b9eff91440e": "skill-d85e3b31-3ead-4c46-8407-d3a47c4caf2b",
    "exercise-d5a84443-ce71-41b2-b80e-eb256ce53f63": "skill-d85e3b31-3ead-4c46-8407-d3a47c4caf2b",
    "exercise-27ede26b-9be5-430c-b54a-2f0918373ad2": "skill-d85e3b31-3ead-4c46-8407-d3a47c4caf2b",
}


def main():
    print("=== DB Cleanup ===\n")

    # ── 1. Patch seeded exercises with correct skill_id ───────────────────────
    print("[1] Patching seeded exercises → skill_id")
    for ex_id, skill_id in SEED_EXERCISES.items():
        r = api("GET", f"/v1/admin/exercises/{ex_id}")
        if r is None or "data" not in r:
            print(f"  ✗ exercise {ex_id} not found — skip")
            continue
        current_skill = r["data"].get("skill_id", "")
        if current_skill == skill_id:
            print(f"  = {ex_id[:20]}… already linked")
            continue
        patch(f"/v1/admin/exercises/{ex_id}", {"skill_id": skill_id})

    # ── 2. Delete duplicate/orphaned exercises ────────────────────────────────
    print("\n[2] Deleting duplicate exercises")
    all_ex = api("GET", "/v1/admin/exercises")
    if all_ex and "data" in all_ex:
        for ex in all_ex["data"]:
            ex_id = ex["id"]
            if ex_id not in SEED_EXERCISES:
                delete(f"/v1/admin/exercises/{ex_id}")

    # ── 3. Delete orphaned/manual skills ─────────────────────────────────────
    print("\n[3] Deleting orphaned/manual skills")
    all_sk = api("GET", "/v1/admin/skills")
    if all_sk and "data" in all_sk:
        for sk in all_sk["data"]:
            if sk["id"] not in KEEP_SKILLS:
                delete(f"/v1/admin/skills/{sk['id']}")

    # ── 4. Delete manual modules ──────────────────────────────────────────────
    print("\n[4] Deleting manual modules")
    all_mod = api("GET", "/v1/admin/modules")
    if all_mod and "data" in all_mod:
        for mod in all_mod["data"]:
            if mod["id"] not in KEEP_MODULES:
                delete(f"/v1/admin/modules/{mod['id']}")

    # ── 5. Delete duplicate course ────────────────────────────────────────────
    print("\n[5] Deleting duplicate courses")
    all_courses = api("GET", "/v1/admin/courses")
    if all_courses and "data" in all_courses:
        for c in all_courses["data"]:
            if c["id"] != KEEP_COURSE:
                delete(f"/v1/admin/courses/{c['id']}")

    # ── 6. Verify final state ─────────────────────────────────────────────────
    print("\n[6] Final state")
    courses = api("GET", "/v1/admin/courses")
    modules = api("GET", "/v1/admin/modules")
    skills  = api("GET", "/v1/admin/skills")
    exs     = api("GET", "/v1/admin/exercises")
    print(f"  Courses:   {len(courses['data'] if courses else [])}")
    print(f"  Modules:   {len(modules['data'] if modules else [])}")
    print(f"  Skills:    {len(skills['data'] if skills else [])}")
    print(f"  Exercises: {len(exs['data'] if exs else [])}")
    if exs:
        no_skill = [e for e in exs["data"] if not e.get("skill_id")]
        print(f"  NOSKILL:   {len(no_skill)}")
    print("\nDone.")


if __name__ == "__main__":
    main()
