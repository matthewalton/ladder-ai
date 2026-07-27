# 0002 — The proposal covers roles, achievements, and skills only

Status: superseded by 0008 (2026-07-21) — the proposal now covers the whole CV

## Context

Profile decisions/0003 deferred `Education` and `Project` models to "whichever
later slice first needs them (likely cv-import)". Including them here would
mean amending the Profile slice's schema and its round-trip criterion
([PROFILE-5]) alongside building this new slice.

## Decision

Deferred again. The proposal covers Roles, Achievements, and skills only.
Education and project content is never silently dropped: the proposal carries
it as not-imported sections, the review lists them ([CVIMPORT-9]), and nothing
outside the scope is merged.

## Consequences

- This run stays a pure new slice; the Profile slice's contract is untouched.
- An imported CV's education/projects do not reach the Profile yet — visible
  in review, so the user knows what didn't land.
- Adding `Education`/`Project` later is an amend to the Profile slice (schema +
  round-trip) plus an amend here (proposal scope + review), in that order.
