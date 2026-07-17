# 0003 — Roadmap-minimal schema: no Education/Project models in this slice

Status: accepted (agreed with the human at the plan stage, 2026-07-17)

## Context

ARCHITECTURE.md §3 sketches `Profile` with `education: [Education]` and
`projects: [Project]` arrays, but ROADMAP.md's slice line for **profile** lists
only `Profile`/`Role`/`Achievement` (+ `SkillTag`, `ContactInfo`).

## Decision

This slice's schema is the roadmap-minimal set: `Profile`, `Role`, `Achievement`,
`SkillTag`, and the `ContactInfo` value type. `Education` and `Project` are added
by whichever later slice first needs them (likely cv-import), as an additive
SwiftData migration and an amendment to this spec's round-trip criterion.

## Consequences

- Smaller round-trip surface now; every persisted field is reachable from the
  editor this slice ships.
- cv-import must amend this slice (new models + round-trip coverage) before it
  can propose education or project entries from a parsed CV.
- ARCHITECTURE.md §3 remains the target shape; this is sequencing, not a
  divergence from it.
