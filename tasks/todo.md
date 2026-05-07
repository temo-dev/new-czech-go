# Tasks — Todo Index

**Active backlog only.** V2..V20 history lives in
[`todo-archive-v2-to-v20.md`](todo-archive-v2-to-v20.md) (73 KB,
frozen).

For per-slice task lists with `[x]` / `[ ]` checkboxes, see the
matching `<slice>-todo.md` file:

- [cefr-level-progression-todo.md](cefr-level-progression-todo.md) — V21 + V21.1 review hotfixes
- [skill-mastery-progress-todo.md](skill-mastery-progress-todo.md) — V19
- [exercise-dashboard-todo.md](exercise-dashboard-todo.md) — V11

## Open V21 items

- [ ] **V21-E2** Manual TestFlight MAN-1..10 acceptance (manual,
  deploy-time, outside automated TDD)
- [ ] **V21-Wiring** `home_screen.dart` embeds `HomeLevelHeader` +
  onboarding router gate (composition-only, no logic)
- [ ] **V21-i18n** Route inline VI strings in V21 widgets through
  `AppLocalizations` (six ARB keys already added in V21-D9)

## Suggestion polish (S1–S8 from V21 review)

Lower priority — none deploy-blockers:

- [ ] S1 Always trust server `next_level` in Flutter (drop client
  fallback compute via `nextCefrLevel`)
- [ ] S2 Derive `_skillOrder` in Flutter from server-provided keys
- [ ] S3 Share a single `HttpClient` between `LevelApi` + `ApiClient`
- [ ] S4 Scope `Timer.periodic(1s)` rebuild to the cooldown caption
  only (not the whole diagnostic table)
- [ ] S5 Tighten `LevelService.ResolveCourseUnlock` empty-level
  passthrough — log + treat as `a2`, not auto-unlocked
- [ ] S6 Replace overloaded empty-string `next_level` with nullable
  field on the wire
- [ ] S7 Include the session payload in the `POST /v1/promotion-attempts`
  201 response so the client doesn't follow up with `GET /v1/mock-exams/:id`
- [ ] S8 Migration 026 backfill — add explicit `created_at < V21_EPOCH`
  guard rather than relying on the placement-taken null sentinel

## Long-running backlog

- [ ] Seed sample content via CMS — at least 1 exercise per type for
  Flutter end-to-end (interview included). Includes B9 reseed:
  demo `cteni_5` exercise listed twice; demo `cteni_6` returned
  with empty `module_id`.
- [ ] Vocab item per-item Polly TTS (deferred from V11).
- [ ] V18.1 pilot — 20×6 photo gold set across 5 learners measuring
  handwriting OCR CER ≤10% before promoting OCR to default mode.

## Archive

Old [`tasks/todo.md`](todo-archive-v2-to-v20.md) (V2..V20 mega-list,
956 lines) is frozen. Each slice from V19 onward maintains its own
`<slice>-todo.md` file.
