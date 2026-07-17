# 0002 — The Profile is created explicitly by the user, never auto-created

Status: accepted (agreed with the human at the plan stage, 2026-07-17)

## Context

The single-profile invariant (root `CONTEXT.md`: exactly one Profile exists)
could be established two ways: the store fetch-or-creates the Profile at launch
so one always exists, or nothing exists until the user creates it.

## Decision

Explicit creation. No Profile record exists until the user acts; the
create-profile empty state is the only creation path, and the store rejects
creating a second Profile once one exists.

## Consequences

- The Profile is optional (`Profile?`) everywhere downstream — cv-import, tailor,
  and later phases must handle Profile-absent rather than assuming one.
- First-run is an honest empty state rather than a silently materialised record;
  nothing is persisted the user didn't ask for.
- The invariant is enforced at the store (throwing on a second create), not by UI
  discipline alone.
