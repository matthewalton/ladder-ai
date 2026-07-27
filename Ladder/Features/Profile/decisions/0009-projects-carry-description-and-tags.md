# 0009 — Projects carry a description and project-level Tags, not points

Status: accepted (agreed with the human at the plan stage, 2026-07-21) —
supersedes 0005

## Context

Imported CVs rendered projects as bullet-point rows shaped like role
achievements (0005), which read as noise on the profile page: a project is
better told as one description than a list of impact statements. The human
asked for projects to hold a description instead of points, with useful Tags
attached to the project itself.

## Decision

`Project` drops its `points` relationship and `Achievement.project` goes away
— an Achievement's parent is only ever a Role. `Project` keeps name, optional
link, the one-line summary shown inline next to the name, and `sortIndex`, and
gains:

- a multi-line `details` description, and
- project-level Tags drawn from the same shared `SkillTag` pool as
  achievements, deduplicated by the [PROFILE-8] rule.

Downstream, tailoring selects whole projects (not points) and CV export
renders a selected project's description and Tags — those slices amend their
own contracts to match.

## Consequences

- [PROFILE-11] (cascade delete of project points) and [PROFILE-12] (a point
  belongs to exactly one parent) are retired: the schema now makes both moot.
- Existing persisted project points are dropped with the schema change — no
  migration (defaulted, flagged: import is a hard refresh and the human
  re-imports the CV anyway).
- `SkillTag` gains a second referrer (`Project`) beside `Achievement`; the
  no-orphan-pruning stance ([PROFILE-6]/[PROFILE-16]) covers both.
- 0005's shared-machinery argument no longer applies: the tailor payload,
  review, and export treat projects as units, so nothing reuses the
  Achievement shape for them.
