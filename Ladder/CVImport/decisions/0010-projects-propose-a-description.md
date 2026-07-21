# 0010 — Projects propose a description and skills, not points

Status: accepted (agreed with the human at the plan stage, 2026-07-21)

## Context

Prompt v3 shaped project content exactly like role achievements — bullet
points with impact metrics — and real imports rendered projects as noisy
bullet lists with no useful tags. The Profile slice reshaped `Project` to a
one-line summary, a multi-line description, and project-level Tags (Profile
decisions/0009); the proposal must match.

## Decision

The import prompt (v4) proposes each project as name, link, one-line summary,
a multi-line description written as prose (the CV's own wording, joined —
never invented), and skill names for the project as a whole. Project points
leave the schema. The proposal's project skills are reviewable items like
achievement skills; excluding one detaches it without excluding the project.

## Consequences

- [CVIMPORT-25] (projects with their points) is retired; its replacement
  criterion promises the new shape.
- The fixture proposal JSON and the review UI's project rows change shape in
  step.
- Tailor and CV export consume whole projects (their own decisions record
  this).
