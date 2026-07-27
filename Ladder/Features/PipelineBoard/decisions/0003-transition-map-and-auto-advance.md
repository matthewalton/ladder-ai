# 0003 — Enforced transition map, auto-advance on first Stage

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

`ApplicationStatus` has carried the full six-case set since cv-export, but
nothing has ever moved an Application off `.applied`. The board makes status
mutable, so the slice had to decide whether drag is free or governed, and
whether the store ever changes status on the user's behalf.

## Decision

Status moves are governed by a fixed transition map, enforced in
`PipelineStore` (the board consults `canMove` to offer only legal targets;
`move(_:to:)` throws `illegalTransition` otherwise):

- draft → applied, withdrawn
- applied → active, rejected, withdrawn
- active → offer, rejected, withdrawn
- offer → withdrawn (declining; nothing else leaves offer)
- rejected, withdrawn → terminal

A same-status drop is a no-op, not an error. `draft → applied` stamps
`appliedAt = .now` when nil and never overwrites an existing value
([PIPEBOARD-9]).

One auto-advance exists: adding the first Stage to an `.applied` Application
sets it `.active` ([PIPEBOARD-7]) — an interview loop starting *is* the
application going active. No other mutation changes status implicitly.

## Consequences

- Timeline (next slice but one) can trust status history to be causally
  ordered — no offer-out-of-nowhere rows.
- Terminal statuses keep closed trails closed; reopening a rejected
  Application means creating a new one (the [CVEXPORT-13] no-dedup stance).
- The map is statics on `PipelineStore`, so tests hit it directly and the
  board stays thin.
- Loosening the map later is a spec amendment to [PIPEBOARD-5]/[PIPEBOARD-6]
  plus an amendment here — not a quiet code change.
