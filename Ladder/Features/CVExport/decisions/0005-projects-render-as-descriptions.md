# 0005 — A selected project renders its description, not bullets

Status: accepted (agreed with the human at the plan stage, 2026-07-21)

## Context

Projects lost their points (Profile decisions/0009) and tailoring now selects
projects whole (Tailor decisions/0007). [CVEXPORT-19]'s render rule — a
project appears when one of its points is selected — has nothing left to
test.

## Decision

A project renders on the tailored CV exactly when the reviewed outcome's
selection includes it: name, link when present, and its description as a
prose block, verbatim from the Profile. The skills line ([CVEXPORT-6]) draws
from selected achievements' Tags and selected projects' Tags as one union.

## Consequences

- [CVEXPORT-19] is retired; its replacement promises the selected-project
  render.
- The renderer drops the per-project bullet list; the description is one
  paragraph block under the project heading.
- No Projects section renders when no project is selected, as before.
