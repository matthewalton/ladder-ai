# 0007 — Projects are selected whole, not point by point

Status: accepted (agreed with the human at the plan stage, 2026-07-21)

## Context

Projects lost their points: the Profile reshaped `Project` to a one-line
summary, a multi-line description, and project-level Tags (Profile
decisions/0009). Per-point project selection ([TAILOR-20]) has nothing left
to reference, and the human chose whole-project selection over
always-render-everything or dropping projects from tailoring.

## Decision

The payload serializes each project as one unit — stable `p…` id, name,
summary, description, and Tags — and the service includes or omits projects
whole for the job description. A selected project travels to the reviewed
outcome as-is: its description is the user's own prose and is never expanded
or reworded (the 0005 stance applied to projects — there is no brief talking
point to grow). Role achievements keep per-point selection and expansion
unchanged.

## Consequences

- [TAILOR-20] is retired; its replacement promises whole-project selection.
- Validation still resolves selections against the union of `a…` and `p…`
  ids; a `p…` id now names a project, not a point.
- cv-export renders a project when the project itself is selected
  (CVExport amends [CVEXPORT-19]).
- The review lists selected projects as units beside the expanded bullets;
  there is nothing to accept or reject per project this slice.
