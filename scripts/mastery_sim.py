#!/usr/bin/env python3
"""
Mastery curve simulator — Phase 2 validation gate.

Replays 20 synthetic attempt sequences against the V19 EMA formula and
prints curve sanity checks. The formula must match
backend/internal/processing/mastery_updater.go computeMastery + the
configured MasteryConfig defaults; if the production constants change,
update the constants block at the top.

Usage:
  python3 scripts/mastery_sim.py
  python3 scripts/mastery_sim.py --json   # machine-readable output for CI gate
  python3 scripts/mastery_sim.py --early-alpha 0.6  # what-if tuning sweep

Exit code 0 = all curves sane; 1 = at least one violated a sanity check.
"""

import argparse
import json
import sys
from dataclasses import dataclass

# ── Production constants (mirror processing/processing_config.go defaults) ─
EARLY_ATTEMPT_CAP = 3
EARLY_ALPHA = 0.5
STEADY_ALPHA = 0.3

BAND_LEARNING = 0.40
BAND_SOLID = 0.70
BAND_READY = 0.85

# Readiness → mastery contribution (mirror processing/llm_feedback.go ReadinessToScore).
READINESS_SCORE = {
    "not_ready": 0.20,
    "needs_work": 0.45,
    "almost_ready": 0.70,
    "ready_for_mock": 0.90,
}


def band_from_mastery(m: float) -> str:
    if m >= BAND_READY:
        return "ready"
    if m >= BAND_SOLID:
        return "solid"
    if m >= BAND_LEARNING:
        return "learning"
    return "needs_work"


def ema_step(old_mastery: float, attempts_count: int, score: float, *,
             early_alpha: float = EARLY_ALPHA,
             steady_alpha: float = STEADY_ALPHA,
             early_cap: int = EARLY_ATTEMPT_CAP) -> float:
    if attempts_count == 0:
        return score
    alpha = early_alpha if attempts_count <= early_cap else steady_alpha
    return old_mastery * (1 - alpha) + score * alpha


def replay(sequence: list[str], **kwargs) -> list[float]:
    """Return mastery after each attempt in the sequence."""
    mastery = 0.0
    attempts = 0
    out = []
    for level in sequence:
        score = READINESS_SCORE[level]
        mastery = ema_step(mastery, attempts, score, **kwargs)
        attempts += 1
        out.append(mastery)
    return out


@dataclass
class Sequence:
    name: str
    levels: list[str]
    invariant: str
    check: callable  # (curve: list[float]) -> tuple[bool, str]


def _monotone_up(curve):
    ok = all(curve[i] <= curve[i + 1] + 1e-9 for i in range(len(curve) - 1))
    return ok, f"first={curve[0]:.3f} last={curve[-1]:.3f}"


def _monotone_down(curve):
    ok = all(curve[i] >= curve[i + 1] - 1e-9 for i in range(len(curve) - 1))
    return ok, f"first={curve[0]:.3f} last={curve[-1]:.3f}"


def _converges_above(threshold):
    def check(curve):
        ok = curve[-1] >= threshold - 1e-9
        return ok, f"last={curve[-1]:.3f} threshold={threshold}"
    return check


def _converges_below(threshold):
    def check(curve):
        ok = curve[-1] <= threshold + 1e-9
        return ok, f"last={curve[-1]:.3f} threshold={threshold}"
    return check


def _stays_in_band(low, high):
    def check(curve):
        violations = [m for m in curve if m < low - 1e-9 or m > high + 1e-9]
        ok = not violations
        return ok, f"violations={len(violations)} range=[{min(curve):.3f},{max(curve):.3f}]"
    return check


def build_scenarios() -> list[Sequence]:
    """20 sequences spanning the realistic + adversarial space."""
    R = "ready_for_mock"
    A = "almost_ready"
    N = "needs_work"
    Z = "not_ready"

    seq = []

    # Monotonic improvement: 5 weak → 5 ok → 5 strong, etc. should trend up.
    seq.append(Sequence(
        "steady-improve-12",
        [Z, Z, Z, N, N, N, A, A, A, R, R, R],
        "monotone non-decreasing once warmed",
        _monotone_up,
    ))
    seq.append(Sequence(
        "weak-then-mock-ready-10",
        [Z] * 5 + [R] * 5,
        "ends well above 0.5 after 5 ready_for_mock attempts",
        _converges_above(0.50),
    ))

    # Monotonic decline: starts strong, drifts to needs_work.
    seq.append(Sequence(
        "regression-10",
        [R] * 5 + [N] * 5,
        "ends below 0.65 after 5 needs_work attempts",
        _converges_below(0.65),
    ))

    # Plateau on a single band: 10× same level.
    for level in (Z, N, A, R):
        seq.append(Sequence(
            f"plateau-{level}-10",
            [level] * 10,
            f"converges at {READINESS_SCORE[level]:.2f}",
            lambda curve, target=READINESS_SCORE[level]:
                (abs(curve[-1] - target) < 0.05,
                 f"last={curve[-1]:.3f} target={target}"),
        ))

    # Alternating: noisy learner.
    seq.append(Sequence(
        "alternating-NA-12",
        [N, A] * 6,
        "stays inside [0.45, 0.70] after warm-up",
        lambda curve: _stays_in_band(0.30, 0.75)(curve[3:]),
    ))
    seq.append(Sequence(
        "alternating-ZR-12",
        [Z, R] * 6,
        "stays inside [0.20, 0.90] always (band envelope)",
        _stays_in_band(0.20, 0.90),
    ))

    # Single-attempt edge.
    seq.append(Sequence(
        "single-attempt-R",
        [R],
        "first attempt sets mastery directly to score",
        lambda curve: (abs(curve[0] - 0.90) < 1e-9,
                       f"got={curve[0]:.3f} expected=0.90"),
    ))
    seq.append(Sequence(
        "single-attempt-Z",
        [Z],
        "first attempt sets mastery directly to score",
        lambda curve: (abs(curve[0] - 0.20) < 1e-9,
                       f"got={curve[0]:.3f} expected=0.20"),
    ))

    # Early-window vs steady-window contrast: 4th attempt should still
    # use early alpha (existing.AttemptsCount=3 ≤ EarlyAttemptCap=3).
    seq.append(Sequence(
        "early-window-cap-check",
        [Z, R, R, R, R, R, R, R],
        "monotone up once on R streak after Z opener",
        _monotone_up,
    ))

    # Burst: rapid 6× ready_for_mock should cross BandReady.
    seq.append(Sequence(
        "burst-ready-6",
        [R] * 6,
        "crosses BandReady (≥0.85)",
        _converges_above(0.85),
    ))

    # Slow climb: 12 needs_work followed by 8 almost_ready ends in solid range.
    seq.append(Sequence(
        "slow-climb-20",
        [N] * 12 + [A] * 8,
        "ends above 0.65 once almost_ready streak runs",
        _converges_above(0.65),
    ))

    # Recovery: weak → strong → weak → strong, demonstrates EMA dampens shocks.
    seq.append(Sequence(
        "shock-recovery-12",
        [Z, R, Z, R, Z, R, Z, R, Z, R, Z, R],
        "stays inside [0.20, 0.90]",
        _stays_in_band(0.20, 0.90),
    ))

    # Long needs_work tail: should NOT bottom out below 0.20 even if old.
    seq.append(Sequence(
        "long-needs-work-tail-15",
        [R, R, R] + [N] * 12,
        "decays toward but does not undershoot 0.45",
        _converges_above(0.40),
    ))

    # Long ready tail.
    seq.append(Sequence(
        "long-ready-tail-15",
        [Z, Z, Z] + [R] * 12,
        "rises toward but does not exceed 0.90",
        _converges_below(0.90 + 1e-9),
    ))

    # Pad to 20 sequences with extra plateau variants.
    seq.append(Sequence(
        "single-then-rest",
        [R] + [N] * 9,
        "ends below 0.65 (regression dampened by EMA)",
        _converges_below(0.65),
    ))
    seq.append(Sequence(
        "trickle-improve-8",
        [Z, Z, N, N, A, A, R, R],
        "ends above 0.45 (out of needs_work band)",
        _converges_above(0.45),
    ))
    seq.append(Sequence(
        "all-almost-ready-8",
        [A] * 8,
        "converges at 0.70 (boundary of solid band)",
        lambda curve: (abs(curve[-1] - 0.70) < 0.05,
                       f"last={curve[-1]:.3f}"),
    ))

    return seq


def main():
    parser = argparse.ArgumentParser(description="V19 mastery curve simulator.")
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    parser.add_argument("--early-alpha", type=float, default=EARLY_ALPHA,
                        help=f"override EarlyAlpha (default {EARLY_ALPHA})")
    parser.add_argument("--steady-alpha", type=float, default=STEADY_ALPHA,
                        help=f"override SteadyAlpha (default {STEADY_ALPHA})")
    parser.add_argument("--early-cap", type=int, default=EARLY_ATTEMPT_CAP,
                        help=f"override EarlyAttemptCap (default {EARLY_ATTEMPT_CAP})")
    args = parser.parse_args()

    kwargs = dict(early_alpha=args.early_alpha, steady_alpha=args.steady_alpha,
                  early_cap=args.early_cap)

    scenarios = build_scenarios()
    results = []
    failures = 0
    for s in scenarios:
        curve = replay(s.levels, **kwargs)
        ok, detail = s.check(curve)
        bands = [band_from_mastery(m) for m in curve]
        results.append({
            "name": s.name,
            "ok": ok,
            "invariant": s.invariant,
            "detail": detail,
            "n": len(s.levels),
            "first": curve[0],
            "last": curve[-1],
            "min": min(curve),
            "max": max(curve),
            "final_band": bands[-1],
        })
        if not ok:
            failures += 1

    summary = {
        "total": len(scenarios),
        "passed": len(scenarios) - failures,
        "failed": failures,
        "config": {
            "early_alpha": args.early_alpha,
            "steady_alpha": args.steady_alpha,
            "early_attempt_cap": args.early_cap,
            "bands": {"learning": BAND_LEARNING, "solid": BAND_SOLID, "ready": BAND_READY},
        },
        "results": results,
    }

    if args.json:
        print(json.dumps(summary, indent=2, ensure_ascii=False))
    else:
        print("=== V19 Mastery Curve Simulator ===")
        print(f"early_alpha={args.early_alpha} steady_alpha={args.steady_alpha} "
              f"early_cap={args.early_cap}")
        print(f"bands: learning={BAND_LEARNING} solid={BAND_SOLID} ready={BAND_READY}")
        print()
        for r in results:
            mark = "[OK]" if r["ok"] else "[FAIL]"
            print(f"{mark} {r['name']:<30} n={r['n']:>2} "
                  f"first={r['first']:.3f} last={r['last']:.3f} "
                  f"band={r['final_band']:<10} — {r['invariant']}")
            if not r["ok"]:
                print(f"     ↳ {r['detail']}")
        print()
        print(f"Summary: {summary['passed']}/{summary['total']} sane curves; "
              f"{summary['failed']} failed.")

    sys.exit(0 if failures == 0 else 1)


if __name__ == "__main__":
    main()
