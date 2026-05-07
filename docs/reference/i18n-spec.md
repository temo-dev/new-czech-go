# i18n Spec

## Purpose
This document defines the contract for multi-language support across the learner app and backend. It covers supported locales, how the locale is chosen, how it flows through the attempt lifecycle, and how it is applied to LLM-generated feedback.

See [i18n-multi-language-support.md](/Users/daniel.dev/Desktop/czech-go-system/docs/ideas/i18n-multi-language-support.md) for product motivation.

## Supported Locales
V1 supports exactly two learner-interface locales:

| Code | Name | Scope |
|---|---|---|
| `vi` | Vietnamese | default, already shipped |
| `en` | English | new in V1 i18n slice |

The following locales are **reserved but not implemented** in V1:
- `cs` Czech — meta-UI only, never appears as a learner-interface choice

Any other locale string sent by a client must be rejected or coerced to `vi`.

## Locale Selection
1. First launch: learner picks locale from a language-selector on the home screen. Default selection `vi`.
2. Choice persisted locally via `SharedPreferences` under key `app.locale`.
3. App language selector is reachable from home screen at any time.
4. Server receives the locale on every attempt create call; server never guesses locale.

There is no device-locale auto-detection in V1. If nothing is persisted, default is `vi`.

## Content Categories

### Translated
- Flutter UI copy (buttons, labels, instructions, errors, empty states, toasts)
- Learner-facing feedback text produced by the LLM: `overall_summary`, `strengths[]`, `improvements[]`, `retry_advice[]`
- Readiness-level display labels (`not_ready` → "Chưa sẵn sàng" / "Not ready")

### Not Translated
- Czech exercise prompts, topic labels, dialogue scenarios, story checkpoints
- `sample_answer` (always natural Czech, regardless of UI locale)
- Transcript text (always Czech)
- CMS admin interface
- Backend log output (English)

### Partially Translated
- Rule-based fallback feedback: V1 keeps Vietnamese strings only. If locale is `en` and LLM fails, backend returns a short neutral English `overall_summary` plus empty strengths/improvements/retry-advice arrays. Frontend shows a generic "Feedback unavailable, try again" card for `en` fallback.

## API Contract Changes

### `POST /v1/attempts` Request
Add optional field:

```json
{
  "exercise_id": "...",
  "client_platform": "ios",
  "client_version": "0.1.0",
  "locale": "en"
}
```

Rules:
- `locale` is optional. If omitted → `vi`.
- Valid values: `vi`, `en`. Any other value → 400 Bad Request with code `invalid_locale`.
- Case-insensitive: `VI` → `vi`.
- Stored on the `Attempt` row and propagated through processing.

### `GET /v1/attempts/{id}` Response
`Attempt` view gains a `locale` field echoing the stored value. Required (not optional) on the response.

### `AttemptFeedback`
No schema change. Existing fields (`overall_summary`, `strengths`, etc.) hold strings in the attempt's locale.

## Backend Plumbing

```
POST /v1/attempts { locale }
  → Attempt.Locale = normalized(locale)
  → store.CreateAttempt persists Locale
  → Processor.ProcessAttempt reads Attempt.Locale
  → LLMFeedbackProvider.GenerateFeedback(exercise, transcript, reliability, locale)
  → system prompt branches on locale
  → response fills AttemptFeedback
```

### LLM Prompt Locale Switch
System prompt has one language-binding clause that varies:

- `vi` → `"All text fields must be in Vietnamese (except sample_answer which must be natural Czech)."`
- `en` → `"All text fields must be in English (except sample_answer which must be natural Czech)."`

All other prompt content (grammar focus, pronunciation focus, output schema) is locale-invariant English meta-prompt.

### Rule-Based Fallback
V1 rule: `buildFeedback` is VI-only. Wrap in a locale-aware shim:

```
buildFeedbackLocalized(exercise, transcript, reliability, locale):
  if locale == "vi":
    return buildFeedback(...)    // existing VI templates
  else:
    return {
      ReadinessLevel: "almost_ready",
      OverallSummary: "Feedback is temporarily unavailable. Please retry.",
      Strengths: [],
      Improvements: [],
      RetryAdvice: ["Record again with a clearer microphone."],
      ...rule-based TaskCompletion and GrammarFeedback in English
    }
```

Translating the full VI template engine to English is V2 work.

## Flutter Plumbing

### Dependencies
- `flutter_localizations` (SDK)
- `intl` (already in transitive deps)

### File Layout
```
flutter_app/
  l10n.yaml
  lib/
    l10n/
      app_en.arb
      app_vi.arb
    core/
      locale/
        locale_provider.dart    // ChangeNotifier + SharedPreferences
        supported_locales.dart  // enum + display labels
```

### LocaleProvider
Global singleton. Exposes:
- `Locale current`
- `void setLocale(Locale next)`
- Persisted to `SharedPreferences` key `app.locale`.
- Notifies listeners on change → `MaterialApp` rebuilds with new locale.

### String Access Pattern
In every widget that renders user-facing text:

```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.homeRecentAttemptsTitle);
```

No direct string literals in production widgets. Exceptions: debug widgets, dev-only screens, developer log text.

### ARB Structure
Hierarchical keys per screen:

```json
{
  "homeTitle": "A2 Mluveni Sprint",
  "homeRecentAttemptsTitle": "Lần thử gần đây",
  "exerciseRecordStart": "Bắt đầu ghi âm",
  "resultReadiness_notReady": "Chưa sẵn sàng"
}
```

Avoid runtime string concatenation; use ARB `placeholders` for variable values.

## Migration Strategy
See [i18n-implementation-plan.md](/Users/daniel.dev/Desktop/czech-go-system/docs/plans/i18n-implementation-plan.md) for phasing. Two vertical slices:

**Slice 1: Locale plumbing end-to-end.** Adds the field, selector, and LLM locale switch. UI remains VI. Immediate user-visible payoff: English LLM feedback.

**Slice 2: Full UI string migration.** Extracts every hardcoded VI string to ARB files. No user-visible behavior change beyond correct rendering in English.

## Validation

### Backend
- Unit test: `POST /v1/attempts` with `locale="en"` stores `en` on attempt row.
- Unit test: `POST /v1/attempts` with `locale="xx"` returns 400.
- Unit test: `LLMFeedbackProvider.GenerateFeedback` with `en` injects English clause into system prompt.
- Unit test: rule-based fallback with `en` returns English neutral summary.

### Flutter
- Widget test: `LocaleProvider` persists + restores from `SharedPreferences`.
- Widget test: changing locale triggers `MaterialApp` rebuild.
- Golden test (optional): result card renders in both locales.

### End-to-End Manual
- Record attempt with `locale=en` → verify feedback strings are English in the result card.
- Record attempt with `locale=vi` → verify feedback unchanged vs today.
- Verify Czech `sample_answer` and transcript remain Czech in both cases.

## Open Questions
- Do we expose the language selector also in a settings screen, or only at first-launch + header widget on home?
- When the LLM fails for `en` learners, should we fall through to Google Translate on the VI template? (V1: no.)
- Should readiness-level display labels be translated by the client (from the fixed enum) or by the server? (V1: client — server returns the enum string, client maps to localized label.)

## Out of Scope for This Spec
- CMS admin locale
- RTL languages
- additional locales beyond `vi` and `en`
- translation memory / translator handoff tooling
- A/B testing different English phrasings

## Current Implementation Status
Not implemented yet. This spec is the contract for the upcoming slice.
