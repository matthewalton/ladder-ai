# 0003 — The review screen is the dedup

Status: superseded by 0007 (2026-07-21) — replace semantics leave nothing on
file to duplicate; the review's role is exclusion

## Context

Importing into a Profile that already has roles can propose items the user
already curated. Options: automatic duplicate detection (match on company +
title, pre-exclude likely duplicates), blocking import into a non-empty
Profile, or leaving rejection to the mandatory review.

## Decision

No automatic duplicate detection in v1. Every proposed item enters review as
included ([CVIMPORT-4]); the per-item review is where the user rejects
anything already on file. Skill names remain the one automatic dedup, via the
existing store logic ([PROFILE-8], [CVIMPORT-8]) — that is identity, not
guesswork.

## Consequences

- No fuzzy-matching policy to spec, tune, or explain; the user stays the
  authority on what counts as a duplicate.
- Re-importing the same CV proposes everything again — the review makes the
  repetition visible rather than hiding it.
- If manual rejection proves tedious, likely-duplicate flagging is an amend to
  this slice, and it changes the review's defaults, not the merge.
