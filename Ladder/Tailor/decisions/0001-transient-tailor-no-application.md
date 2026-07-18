# 0001 — The tailor flow is transient; no Application model in this slice

Status: accepted (agreed with the user at plan stage, 2026-07-18)

## Context

ROADMAP gives this slice a "New Application sheet", but `Application` is a
Phase-2 (Pipeline) model per ARCHITECTURE.md §3–4, and the next slice —
cv-export — is where "Application persisted with immutable `cvSnapshot`"
appears. CV Import set the in-repo precedent of a transient proposal→review
flow.

## Decision

Nothing in the tailor flow is persisted. The sheet's inputs (company, role
title, job description), the tailor result, and the reviewed outcome live in
memory for the session only. The `Application` model and persistence of the
outcome arrive with cv-export.

## Consequences

- Quitting mid-review loses the session; acceptable for this slice.
- The Phase-2 model stays out of Phase 1; no schema change, no migration.
- cv-export owns the write; the reviewed outcome type is designed as its
  input.
- The sheet is named "tailor sheet" in this slice's language, not "New
  Application sheet", because no Application exists yet.
