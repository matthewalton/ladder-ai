# 0001 — Import requires an existing Profile

Status: superseded by 0007 (2026-07-21) — import may now create the Profile

## Context

Root `CONTEXT.md`'s example dialogue said import creates a Profile "only if
none exists", while Profile decisions/0002 (agreed later, at that slice's plan
stage) made the create-profile empty state the only creation path. The two
conflicted; one had to win.

## Decision

Profile decisions/0002 stands. Import never creates the Profile: the flow
refuses to start when none exists (`ImportError.profileRequired`), and import
entry points appear only inside an existing Profile — e.g. the add-first-role
empty state anticipated by [PROFILE-10]. Root `CONTEXT.md`'s dialogue line was
corrected as part of this decision.

## Consequences

- One creation path to reason about; the single-profile invariant keeps a
  single enforcement point ([PROFILE-4]).
- First-run import is two steps: create the Profile (name + headline), then
  import. Accepted cost for v1.
- If import-as-first-run ever matters, it is an amend to Profile
  decisions/0002 and this decision together, not a quiet workaround.
