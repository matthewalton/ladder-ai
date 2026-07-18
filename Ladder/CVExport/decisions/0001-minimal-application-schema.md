# 0001 — Roadmap-minimal Application schema, immutable snapshot

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

ARCHITECTURE.md §3 defines the full `Application` model, including an ordered
chain of `Stage`s — but Stages are the Phase 2 pipeline's concern, and this
slice only needs what export writes. The Profile slice set the precedent
(Profile decisions/0003): model what the roadmap slice needs, keep §3 as the
target shape.

## Decision

`Application` ships roadmap-minimal: `company`, `roleTitle`, `jobDescription`,
`status`, `cvSnapshot`, `cvSelectionRationale`, `createdAt`. No `Stage` model,
no relationship to it. `ApplicationStatus` defines the full §3 case set
(`draft`, `applied`, `active`, `offer`, `rejected`, `withdrawn`) since the
enum is the cheap part — but export only ever writes `.applied`.

`cvSnapshot` is written exactly once, at export, and never mutated — the
historical record of what was sent must be exact (ARCHITECTURE.md §3
invariant). No API on the store updates it.

The model lives in this slice's `src/` — the slice that introduces a model
owns its file, as `ProfileModels.swift` does in the Profile slice. There is
no `Shared/Models/` folder.

## Consequences

- Phase 2 adds `Stage` and the relationship as a schema migration, plus the
  status transitions; nothing here blocks that.
- Every field is exercised by the round-trip test [CVEXPORT-11].
- The plan document's assumption that models live in `Shared/Models/` was
  wrong and is corrected here.
