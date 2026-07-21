# 0006 — The CV summary is generated per application, never stored

Status: accepted (agreed with the human at the plan stage, 2026-07-21)

## Context

Real CVs open with a summary paragraph. CV import deliberately routes it to
not-imported (CVImport decisions/0008), and the Profile schema has no summary
field. The question was where a summary should come from at all: stored on
the Profile and copied onto every CV, or generated fresh.

## Decision

Generated at tailor time, per application. The tailor result gains a required
`summary` field: a short opening paragraph tailored to the pasted job
description, grounded strictly in payload facts — years of experience derived
from role dates, actual roles, tech, metrics — under the same no-invention
stance as bullets. It travels through the review and reviewed outcome
verbatim and is rendered by cv-export under the identity header; it is never
written to the Profile.

## Consequences

- The Profile schema stays summary-free; the import's not-imported routing of
  the CV's own summary paragraph is coherent, not a gap.
- `Prompts/tailor.md` moves to v4; a result missing the summary is a schema
  failure and feeds the single repair request (decisions/0004).
- Each application's CV opens with a summary written against that JD — the
  point of tailoring.
