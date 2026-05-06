# CEFR Level Progression — UX Spec

> Pair with `docs/specs/cefr-level-progression.md` (functional spec) and
> `docs/ideas/cefr-level-progression.md` (idea note). This file owns
> **screen inventory, flow, design tokens, and pre-delivery UX
> checklist**. Decided 2026-05-06.

## Audience & Style

- **Audience**: adult Vietnamese learners preparing for Czech `trvalý
  pobyt` A2 (and B1 občanství). Not children.
- **Style**: reuse existing Babbel-inspired tokens
  (`AppColors` orange `#FF6A14` + teal `#0F3D3A`, cream surface
  `#FBF3E7`). **Do not introduce a new style system** (claymorphism,
  glassmorphism, etc.) — fails AGENTS.md scope discipline.
- Icons: Lucide / vector only. **No emoji as icons** (`lock`,
  `award`, `target`, `check-circle`).

## User Flow

```
A. ONBOARDING (first launch)
   Splash → Welcome → "Bạn đã học tiếng Czech bao lâu?"
   → PlacementTestScreen (15 items × 4 skills, ~12 min)
       ├─ skip → default A0
       └─ submit → score → set users.current_level
   → PlacementResultScreen ("Bạn đang ở A1") → Home

B. DAILY LEARN
   Home (LevelBadge + LevelProgressRing)
     → Course list (filtered by level ≤ current_level)
        ├─ unlocked → existing Module → Exercise flow
        ├─ demo (1 per upper level) → exercise (no mastery write)
        └─ locked → LockedCourseSheet (mastery delta + CTA)
     → PromotionBanner (when mastery threshold met)
        → "Sẵn sàng thi A2 → B1?" CTA

C. PROMOTION EXAM
   Banner tap → PreExamScreen (rules, time, retake policy)
     → Confirm → MockTestRunner (existing UI, is_promotion=true)
     → Submit → scoring (skeleton)
     → PromotionResultScreen
         ├─ PASS → celebration (badge drop-in spring)
         │         → home auto-refresh, next-level courses unlock
         └─ FAIL → diagnostic table (skill × score × delta)
                   → 24h cooldown timer
                   → "Luyện skill yếu nhất" deep-link
```

## Screen Inventory

| Screen | New / Modify | Notes |
|---|---|---|
| `WelcomeScreen` | new | Onboarding gate before placement |
| `PlacementTestScreen` | reuse `MockTestRunner` + `is_placement` flag | Same UI layer |
| `PlacementResultScreen` | new | Score → level reveal animation |
| `HomeScreen` | modify | Add `LevelBadge` + `LevelProgressRing` top |
| `CourseListScreen` | modify | Lock state, demo state, level chip |
| `LockedCourseSheet` | new | Bottom sheet — mastery delta, CTA |
| `PromotionBanner` | new | Sticky home card when ready |
| `PreExamScreen` | new | Rules + confirm, retake policy |
| `PromotionResultScreen` | new | Pass = celebration, Fail = diagnostic |
| `LevelHistoryScreen` | new (optional V2) | Profile → "Hành trình của bạn" |

## Component Specs

### `LevelBadge` (top-right of home AppBar)

```
┌──────────────────┐
│  [A1] ●●○○       │   orange chip + 4-dot ladder
│  Đang học A2     │
└──────────────────┘
```

- Chip background `AppColors.primaryContainer`, text
  `onPrimaryContainer`.
- Dots: `surfaceContainerHighest` (locked) → `success` (passed) →
  `primary` (current).
- Tap target ≥48dp; `Semantics(label: "Cấp độ hiện tại A1, đang học A2")`.
- Tap → `LevelHistoryScreen`.

### `LevelProgressRing` (home hero)

- 6 arcs = 6 skills (`noi`/`viet`/`nghe`/`doc`/`tu_vung`/`ngu_phap`).
- Each arc fills by `mastery_pct`, colored by score band
  (`scoreExcellent` / `scoreGood` / `scoreFair` / `scorePoor`).
- Center label: "A2 → B1" + "73% sẵn sàng".
- When **all** skills ≥ threshold → ring pulse animation (300ms,
  spring) + reveal CTA "Mở khoá thi nâng cấp".
- Reduced motion: skip pulse, show static "Sẵn sàng" badge.

### `CourseListItem` — locked variant

```
┌─────────────────────────┐
│ [icon:lock]  B1 — Občanství │
│ ─────────────────────── │
│ Hoàn thành A2 mastery   │
│ ▓▓▓▓▓▓▓░░░ 73% / 80%    │
│ [Xem demo →]            │
└─────────────────────────┘
```

- Surface `surfaceContainerLow`, border `outlineVariant`.
- Padlock = Lucide SVG, **not** emoji.
- Progress bar uses `AppColors.primary` fill against
  `surfaceContainerHigh` track.
- Demo button = ghost variant; primary CTA disabled with reduced
  opacity (0.4) + `Semantics(enabled: false)`.

### `PromotionResultScreen` — Pass

- Top: success gradient (`success` → `successContainer`).
- Badge SVG: spring drop-in, 400ms enter / 250ms exit.
- Headline: "Bạn đã lên B1!" — `AppTypography.displayMedium`.
- Sub: "Đề thi `trvalý pobyt` đạt 78%. Mở khoá 12 module B1."
- CTAs: primary "Khám phá B1", ghost "Về trang chủ".
- Haptic: `HapticFeedback.heavyImpact` once on enter.
- Reduced motion: skip confetti, badge fades in 200ms.

### `PromotionResultScreen` — Fail

- Surface neutral cream — **do not use full red**, avoid demoralizing.
- Headline: "Chưa đạt — luyện thêm nhé".
- Diagnostic table:

  ```
  Nghe   ████████░░ 65%  cần ≥70%   -5%
  Đọc    █████████░ 78%  ✓
  ```

- Cooldown timer: live "Có thể thi lại sau 23:42:11".
- CTA: "Luyện skill yếu nhất" → deep-link to course filtered by
  failing skill_kind.
- Mastery is **not** decremented on fail (avoid double punishment).

## Information Hierarchy — Home

```
┌─ AppBar ─────────────── [LevelBadge A1] [Profile] ─┐
├─ LevelProgressRing (hero) ──────────────────────────┤
│  6-skill mastery ring + "A1 → A2: 73%"              │
├─ PromotionBanner (conditional) ─────────────────────┤
│  "Sẵn sàng thi nâng cấp →"                          │
├─ Continue learning card (existing) ─────────────────┤
│  Last exercise resume                                │
├─ Course list ───────────────────────────────────────┤
│  Unlocked   (A0, A1)                                 │
│  Current    (A2 — chipped "Đang học")                │
│  Demo       (B1 — 1 sample exercise)                 │
│  Locked     (B1 full — padlock + delta)              │
└──────────────────────────────────────────────────────┘
```

## Pre-Delivery UX Checklist

| Check | Apply To |
|---|---|
| Touch target ≥48dp | LockedCourseSheet CTA, demo button, banner, badge |
| Color-not-only | Lock = padlock icon + text + opacity, never gray-only |
| Reduced motion | Skip confetti, ring pulse, badge spring — fall back static |
| Semantics labels | Locked card announces mastery delta + CTA |
| Dynamic Type | Level badge/headlines reflow without truncation |
| Empty state (A0) | Home: "Bắt đầu bài đầu tiên →" with single CTA |
| Mastery feedback | `HomeProgressCard.refresh()` on pop-back (V20.1 pattern) |
| Destructive separation | "Reset level" lives in Settings, not near promotion CTA |
| Dark mode | All states tested separately (existing token set already maps) |
| Safe areas | Promotion banner respects bottom CTA bar offset |

## Anti-patterns Avoided

- Emoji icons (use Lucide SVG: `lock`, `award`, `target`, `check-circle`)
- Confetti blocking taps (overlay must allow dismiss anytime)
- Harsh "Bạn fail rồi" copy (use soft "Chưa đạt — luyện thêm")
- Locked content rendered in low-contrast gray (use surface variant)
- Modal block during scoring (use skeleton + cancel option)
- Per-screen ad-hoc colors (must come from `AppColors` tokens)
- Mixing icon styles (filled vs outline) at the same hierarchy

## Open UX Questions

1. **Placement test length** — 12 min may be too long day-0. A/B with a
   6 min "quick placement" + optional full extension.
2. **Banner trigger timing** — instant when mastery hits threshold, or
   end-of-session only? Lean: end-of-session (avoid mid-exercise
   distraction).
3. **B1 demo selection** — `nghe` (low effort) or `viet` (high signal)?
   Lean: `nghe` for first impression.
4. **Promotion fail mastery effect** — confirmed: **no decrement**, only
   24h cooldown.
5. **Re-onboarding for existing A2 users** — auto-assign `current_level
   = a2` on migration, skip placement test? Recommend: yes, with an
   in-app banner offering optional placement re-test.

## Localization

Every new string goes through ARB → `AppLocalizations`. VI and EN key
counts must match (per `flutter` conventions in AGENTS.md). Initial
keys (non-exhaustive):

- `levelBadgeCurrent`, `levelBadgeStudying`
- `placementTestIntroTitle`, `placementTestIntroBody`,
  `placementTestSkipCta`, `placementTestStartCta`
- `placementResultHeadline` (with `{level}` placeholder),
  `placementResultBody`
- `lockedCourseTitle`, `lockedCourseRequirement` (with `{percent}`),
  `lockedCourseDemoCta`
- `promotionBannerTitle`, `promotionBannerCta`
- `preExamRulesTitle`, `preExamRulesBody`, `preExamConfirmCta`,
  `preExamCancelCta`
- `promotionPassHeadline`, `promotionPassBody`,
  `promotionPassExploreCta`, `promotionPassHomeCta`
- `promotionFailHeadline`, `promotionFailCooldown` (with `{hms}`),
  `promotionFailDeepLinkCta`
