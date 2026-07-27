# 0009 — Skills are grouped per CV by the service, not categorised on the model

Status: accepted (agreed with the human at the plan stage, 2026-07-23)

## Context

The CV template's skills section is a two-column categorised table
(CVExport decisions/0007's reference CV), but `SkillTag` has no category.
The alternatives were a `category` field on `SkillTag` (a global taxonomy
the user must curate, and one grouping forced on every application) or
grouping at render time with heuristics (invents structure the service can
do better, JD in hand).

## Decision

The tailor result carries the grouping: the service names categories over
the selection's Tag union as part of the same run, behind a version bump of
`Prompts/tailor.md` ([TAILOR-24]). The grouping is per-CV and transient —
it travels through the reviewed outcome to cv-export's renderer
([CVEXPORT-23]) and is never persisted onto `SkillTag`.

## Consequences

- No model change; no user-facing taxonomy to maintain.
- Validation bounds the grouping to the selection's Tag union — the
  CVExport decisions/0004 vocabulary rule survives, grouped instead of flat.
- Different applications may group the same skills differently — deliberate:
  the JD decides what reads as a category.
- A grouping failure feeds the standard single repair (decisions/0004).
