# 0004 — Education, Project, and interests land in this slice

Status: accepted (agreed with the human at the plan stage, 2026-07-21).
Supersedes 0003.

## Context

0003 deferred `Education`/`Project` to "whichever later slice first needs them
(likely cv-import)". The CV-page redesign made the Profile editor itself that
slice: a page that reads like a CV needs Education, Projects, and Interests
sections to edit.

## Decision

This slice owns `Education`, `Project`, and the Profile's ordered `interests:
[String]` (interests are an attribute, not a model — ordered, no relationships,
mirroring `Achievement.tech`). The migration is purely additive: new entities,
new to-many relationships with stored empty defaults, one defaulted array
attribute, one new optional `Achievement.project` reference. No stored schema
name changes — SwiftData lightweight migration carries existing stores forward.

## Consequences

- [PROFILE-5]'s round-trip criterion covers the full new surface.
- cv-import can later propose education/project entries without amending the
  schema first.
- ARCHITECTURE.md §3's target shape is now implemented (plus interests, which
  it did not sketch).
