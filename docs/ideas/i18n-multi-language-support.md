# i18n Multi-Language Support

## Problem Statement
The product today ships Vietnamese-only copy and Vietnamese-only learner feedback. The underlying exam (`trvaly pobyt A2`) is not Vietnamese-specific — English-speaking residents in Czechia also need to pass it. Shipping Vietnamese-only locks out a second audience that already shares the same exam goal.

## Recommended Direction
Treat the learner's **interface language** as a first-class profile attribute, not a build-time constant. The learner picks a UI language once; every screen renders in that language, and every feedback string the LLM generates is produced in that same language.

Czech content stays Czech (prompts, sample answers, scoring rubric labels that refer to Czech grammar). Learner-facing explanatory text — task instructions, button labels, readiness summaries, strengths, improvements, retry advice — is translated.

## Supported Languages for V1
- `vi` Vietnamese (primary, already shipped)
- `en` English (second audience)

No other languages are in V1 scope. Chinese, Russian, Ukrainian, etc. are explicitly out-of-scope for V1 and should not drive architecture complexity.

## Why Not Auto-Detect?
Device locale auto-detection is unreliable for this audience: a Vietnamese learner on an English-system iPhone still wants Vietnamese feedback. Explicit user choice on first launch is the only reliable signal.

## Why Translate LLM Feedback Instead of UI-Only?
Feedback is the primary value of the app. A learner who picks English UI but gets Vietnamese feedback blocks on every result. Translating UI without translating feedback would be a worse experience than translating neither.

## Key Assumptions to Validate
- [ ] English-speaking `trvaly pobyt A2` candidates exist in meaningful numbers in Czechia.
- [ ] A single Claude prompt with a locale switch produces acceptable quality in both Vietnamese and English.
- [ ] Learners tolerate Czech-only sample answers and Czech-only model audio regardless of UI language.
- [ ] One-time language choice at first launch is enough; no mid-session switch need.

## Non-Goals
- per-exercise language override
- translating Czech prompts, exercise content, or sample answers
- translating CMS admin interface
- machine-translating user-generated content
- RTL language support
- currency / date-format localization beyond what Flutter provides out-of-the-box

## Out of Scope for V1
- automated translation quality regression tests
- translator workflow tooling
- crowdsourced translations
- more than 2 languages

## Risks
| Risk | Impact | Mitigation |
|---|---|---|
| Claude produces inconsistent English vs Vietnamese quality | High | Same prompt skeleton, only language-binding clause differs. Spot-check a real attempt in both locales before declaring V1 done. |
| Rule-based fallback becomes bilingual duplication | Medium | V1 rule-based fallback stays VI-only. If LLM fails and locale is EN, learner sees a short neutral EN fallback summary plus VI details. Log this so we can measure LLM reliability. |
| Mixed locales on one device if multiple users share it | Low | Per-profile locale storage is out of V1 scope; device-level locale is acceptable. |
| Feedback asks Claude to cite Czech phrases in EN prose | Low | Prompt already instructs Claude to quote exact Czech phrases. Czech citation format is locale-agnostic. |

## Related Docs
- `docs/specs/i18n-spec.md` — technical contract for locale plumbing
- `docs/plans/i18n-implementation-plan.md` — phased build plan
- `docs/specs/scoring-pipeline.md` — how LLM feedback integrates today
- `docs/specs/api-contracts.md` — where the `locale` field lands on attempt create
