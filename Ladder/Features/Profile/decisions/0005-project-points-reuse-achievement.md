# 0005 — Project points reuse the Achievement model

Status: accepted (agreed with the human at the plan stage, 2026-07-21)

## Context

Projects need brief, taggable points that tailoring can select and expand, just
like role achievements. Either a new `ProjectPoint` model or the existing
`Achievement` could carry them.

## Decision

`Achievement` gains an optional `project` reference beside its optional `role`;
a point belongs to exactly one parent ([PROFILE-12]), enforced by the store's
creation pathways, never by the schema. A parallel `ProjectPoint` model would
have forced a second `SkillTag` inverse relationship and duplicated the entire
tag/dedup, tailor-payload, review, and CV-export machinery; reuse keeps all of
it working on one type.

## Consequences

- `Achievement.role` is now semantically optional: future slices must not
  assume every Achievement hangs off a Role. Debrief/PrepPack are unaffected —
  they traverse `role.orderedAchievements`, so project points are invisible to
  them.
- `sortIndex` is namespaced within the owning parent.
- Tailoring can serialize project points through the same payload shape as role
  achievements (ids `p1…` vs `a1…`).
