# i18n Implementation Plan

> **Status (2026-04-25):** Slice 1 shipped end-to-end (backend locale field, HTTP validation, LLM locale plumbing, Flutter provider + selector + persistence). Slice 2 shipped: full ARB catalog for learner screens (home, history, exercise, analysis, mock exam, review). Audit found zero remaining user-facing VI/EN literals on learner surfaces. Only `feedback_card.dart:50` has a `'• '` bullet glyph (non-translatable typographic separator).

## Goal
Ship multi-language support (`vi`, `en`) end-to-end: learner-picked interface language drives both UI copy and LLM-generated feedback.

See [i18n-multi-language-support.md](/Users/daniel.dev/Desktop/czech-go-system/docs/ideas/i18n-multi-language-support.md) for motivation and [i18n-spec.md](/Users/daniel.dev/Desktop/czech-go-system/docs/specs/i18n-spec.md) for the contract.

## Strategy
Two vertical slices. Keep the app shippable after each slice.

- **Slice 1** — plumbing + feedback. Lands the locale field across Flutter → API → LLM. UI stays VI. Learner gets English feedback immediately when they select `en`.
- **Slice 2** — UI string migration. Extracts every hardcoded VI string into ARB files. No API change. No backend change.

Slice 1 is higher value per line of code: one user-facing control, one prompt switch, immediate result. Slice 2 is mechanical but touches every screen.

---

## Slice 1: Locale Plumbing + LLM Feedback Locale

### Task 1.1: Backend — `locale` field on Attempt
**Files:**
- `backend/internal/contracts/types.go` — add `Locale string` to `Attempt` struct and to `CreateAttemptRequest`.
- `backend/internal/store/attempt_store.go` — add `locale` column to attempt table + migration.
- `backend/db/migrations/XXXX_add_attempt_locale.sql` — new migration adding `locale TEXT NOT NULL DEFAULT 'vi'`.
- `backend/internal/store/postgres_attempts.go` — include `locale` in insert/select.
- `backend/internal/store/memory_store.go` — in-memory parity.

**Acceptance:**
- [ ] New attempt defaults to `locale='vi'` when request omits the field.
- [ ] Request with `locale='en'` is persisted.
- [ ] Invalid locale values rejected at HTTP layer with 400 + `invalid_locale` code.

### Task 1.2: Backend — HTTP validation + response
**Files:**
- `backend/internal/httpapi/server.go` — validate incoming `locale`, normalize to lowercase, reject unknown.
- `backend/internal/httpapi/attempt_view.go` (or equivalent) — include `locale` in attempt response.

**Acceptance:**
- [ ] `curl -d '{"locale":"xx"}'` → 400.
- [ ] `curl -d '{"locale":"EN"}'` → stored as `en`.
- [ ] `GET /v1/attempts/{id}` returns `locale` field.

### Task 1.3: Backend — Plumb locale to LLM
**Files:**
- `backend/internal/processing/llm_feedback.go` — extend interface:
  ```go
  GenerateFeedback(exercise, transcript, reliability, locale string) (AttemptFeedback, error)
  ```
- `backend/internal/processing/processor.go` — read `attempt.Locale`, pass to provider.
- `backend/internal/processing/llm_feedback.go` — locale-aware system prompt clause.

**Acceptance:**
- [ ] Attempt with `locale='en'` → Claude system prompt includes `"All text fields must be in English"`.
- [ ] Attempt with `locale='vi'` → unchanged from current behavior.

### Task 1.4: Backend — Rule-based fallback for `en`
**Files:**
- `backend/internal/processing/feedback.go` (or wherever `buildFeedback` lives) — wrap in `buildFeedbackLocalized(exercise, transcript, reliability, locale)`.
- Add neutral English fallback path.

**Acceptance:**
- [ ] When LLM fails and locale=`en`, learner sees a short English summary instead of Vietnamese templates.
- [ ] When LLM fails and locale=`vi`, behavior unchanged.

### Task 1.5: Flutter — LocaleProvider + persistence
**Files:**
- `flutter_app/pubspec.yaml` — confirm `shared_preferences` present, add if missing.
- `flutter_app/lib/core/locale/locale_provider.dart` — ChangeNotifier.
- `flutter_app/lib/core/locale/supported_locales.dart` — enum + display labels (hardcoded EN/VI for the selector itself since it must render before locale is loaded).
- `flutter_app/lib/main.dart` — wrap `MaterialApp` with `ChangeNotifierProvider<LocaleProvider>` (or equivalent), wire `locale` param.

**Acceptance:**
- [ ] App restart preserves previously selected locale.
- [ ] First launch defaults to `vi`.

### Task 1.6: Flutter — Locale selector UI
**Files:**
- `flutter_app/lib/features/home/widgets/locale_selector.dart` — dropdown or segmented control.
- `flutter_app/lib/features/home/home_screen.dart` — mount selector in header.

**Acceptance:**
- [ ] User can toggle between VI and EN from home screen.
- [ ] Selection triggers `LocaleProvider.setLocale()`.

### Task 1.7: Flutter — Send locale on attempt create
**Files:**
- `flutter_app/lib/core/api/api_client.dart` — read from `LocaleProvider` (injected), include `locale` in `POST /v1/attempts` body.
- `flutter_app/lib/models/models.dart` — add `locale` to Attempt model.

**Acceptance:**
- [ ] Network capture confirms `locale` field present in create-attempt payload.
- [ ] Attempt view shows stored locale.

### Slice 1 Verification
- `make backend-build && make backend-test`
- `make flutter-analyze && make flutter-test`
- Manual: start app, switch to EN, record attempt, verify feedback text is English.
- Manual: switch back to VI, record attempt, verify feedback unchanged from today.
- Manual: cold-start app, verify last-used locale is restored.

---

## Slice 2: UI String Migration

### Task 2.1: Flutter i18n infra
**Files:**
- `flutter_app/l10n.yaml`
- `flutter_app/lib/l10n/app_vi.arb`
- `flutter_app/lib/l10n/app_en.arb`
- `flutter_app/pubspec.yaml` — enable `flutter: generate: true`.

**Acceptance:**
- [ ] `flutter pub get` generates `AppLocalizations` class.
- [ ] Smoke widget can call `AppLocalizations.of(context)!.helloWorld`.

### Task 2.2: Catalog hardcoded strings
Scan every file under `flutter_app/lib/` for user-visible string literals. Group by screen/widget into ARB keys. Commit ARB files with full VI catalog + EN translations.

**Deliverable:** Two ARB files with matched key sets. CI lints matched-key invariant.

### Task 2.3: Migrate widgets incrementally
Priority order (highest learner impact first):
1. Home screen (`home_screen.dart`, recent attempts list)
2. Exercise screen (prompt, recording controls, status pills)
3. Result card (readiness label, strengths/improvements headers, retry button)
4. Errors, empty states, toasts
5. Debug/dev widgets (defer; low priority)

One PR per screen group. Each PR:
- Replace literals with `AppLocalizations.of(context)!.xxx`.
- Add keys to both ARB files.
- Run `make flutter-analyze` + `make flutter-test`.

### Task 2.4: Readiness-level display labels
**Files:**
- `flutter_app/lib/features/exercise/widgets/result_card.dart` — map enum (`not_ready`, `almost_ready`, `ready_for_mock`, `exam_ready`) through `AppLocalizations`.

Server returns the enum string; client maps to localized label.

### Slice 2 Verification
- Every production widget renders without hardcoded VI literals (grep check).
- Switching locale on home screen updates every screen after navigation.
- Both ARB files have identical key sets (CI check).

---

## Scope Discipline
- Do not translate CMS in this plan.
- Do not add a third locale in this plan.
- Do not migrate to `riverpod` or another state solution just for i18n — use whatever state pattern is already present.
- Do not restructure the Flutter feature folder layout; only add `core/locale/` and `l10n/`.

## Risks
| Risk | Slice | Mitigation |
|---|---|---|
| Claude English output quality disappoints vs Vietnamese | 1 | Spot-check 3 attempts per locale before declaring slice done. Tune prompt clause if needed. |
| ARB key explosion makes translations unmaintainable | 2 | Group by screen. Avoid one-key-per-sentence for dynamic text; use placeholders. |
| Missing translation silently falls through to key name | 2 | Enable `flutter_localizations` strict mode (fail build on missing keys). |
| Learner changes locale mid-attempt | 1 | Locale is captured at attempt create; mid-attempt switch affects next attempt only. Documented in spec. |
| Mock/test fixtures encode `locale=vi` implicitly | 1 | Default is `vi` on server; existing tests continue to pass without edits. |

## Current Status
Slice 1 pending. Slice 2 pending. Start with Slice 1 Task 1.1 after this plan is reviewed.
