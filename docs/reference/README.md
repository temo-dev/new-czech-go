# Reference

Stable, always-current technical contracts. These docs describe how the
system **is supposed to work right now** — they are kept up-to-date as
behaviour changes. When code and reference disagree, fix the code (or
update the reference if the change was intentional).

For the per-slice history of how each contract was *built*, see
`docs/specs/` (frozen post-ship slice specs) and `docs/ideas/` (one-pagers).

## Index

| File | Owns |
|---|---|
| [api-contracts.md](api-contracts.md) | HTTP wire shapes (request/response payloads, error envelopes) |
| [attempt-state-machine.md](attempt-state-machine.md) | Attempt lifecycle: created → uploaded → transcribing → scoring → completed |
| [content-and-attempt-model.md](content-and-attempt-model.md) | Exercise type catalog (V8 flat schema) and attempt → feedback shapes |
| [scoring-pipeline.md](scoring-pipeline.md) | LLM + objective scoring rules, readiness levels, V19 mastery hook |
| [infrastructure-baseline.md](infrastructure-baseline.md) | V1 baseline + the LLM / TTS / OCR env-var table |
| [learner-profile-identity.md](learner-profile-identity.md) | V17 user account model: signup, auth tokens, profile fields |
| [i18n-spec.md](i18n-spec.md) | ARB key conventions, VI/EN parity, CMS inline-string boundary |
| [voice-selection-spec.md](voice-selection-spec.md) | TTS voice routing (V8 voice registry) |

## When to update

Update a reference doc the moment the contract it describes changes.
Update **before** you ship the slice — reviewers should be able to read
the reference and see what the new endpoint will look like.

If the contract change is large enough to deserve a slice (V21-style),
write the slice in `docs/specs/<slice>.md` first; once the slice ships,
fold the new behaviour into the relevant reference doc and link the
slice spec from the section it touches.
