# 0011 — tech merges into Tags: hard removal, versioned migration, store backup

Status: accepted (agreed with the human at plan, 2026-07-26)

## Context

Ticket #162 settled one flat Tag vocabulary (root `CONTEXT.md`: Tag; root ADR
0005): `Achievement.tech` was a parallel typed field beside Tags — exactly
what the vocabulary rules out. PipelineBoard decisions/0001 kept the app on
implicit lightweight migration and recorded that "the first destructive
schema change in a later phase is the moment to introduce versioned schemas".
Dropping a non-optional attribute is that change. The July 2026 store loss
(root ADR 0004) sets the bar for how carefully a destructive migration must
treat the one store file.

## Decision

- `tech` is removed from `Achievement` now — hard removal, not a soft retire
  behind a deprecation. Chosen by the human over soft-retire, with the July
  history on the table.
- The app gains its first `VersionedSchema` pair and `SchemaMigrationPlan`:
  a custom stage folds each achievement's tech strings into the shared Tag
  pool by the [PROFILE-8] rule, then the property is gone ([PROFILE-24]).
- Before the custom stage runs, the store file is copied to a sibling backup
  path ([PROFILE-25]) — the safety net that makes hard removal acceptable.
- The proposal and payload shapes follow: import proposes one `tags` array
  (CVImport decisions/0011), and the tailor/debrief/prep-pack payloads drop
  `tech` — form-only there, defended by each slice's prompt-equality
  criteria (e.g. [TAILOR-5]).

## Considered options

- _Soft retire_ — keep `tech`, stop writing it. Rejected: two vocabularies
  linger, every payload carries a dead field, and the migration debt only
  grows.
- _No backup_ — trust the migration. Rejected; ADR 0004 is the reason this
  repo does not trust first-run migrations with the only copy.

## Consequences

- A pre-migration fixture store joins `LadderTests/Fixtures/` before the
  change lands, and is never regenerated ([PROFILE-24]; the [PIPEBOARD-2]
  pattern). The Phase 1 fixture store keeps defending the older boundary.
- The detail rail loses its tech editor; the replace pathway and the import
  proposal lose their `tech` fields.
