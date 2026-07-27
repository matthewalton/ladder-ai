# 0009 — The on-demand JD scan door opens the full Match review

Status: agreed (2026-07-27)

## Context

Root CONTEXT.md promises the JD scan runs "as the first step of tailoring,
and on demand". The tag arc's slice 3 delivered the tailor-flow step
([TAILOR-43]–[TAILOR-51]); the application detail had no Match surface and
no way to scan outside tailoring — `JDScanStore` was only ever constructed
inside `TailorFlowStore`. A summary-only door was considered: the scan
persists the Match and the detail shows score, matched Tags and gaps, with
the scan's Tag suggestions discarded.

## Decision

Scan JD on the application detail runs the scan and presents the same Match
review the tailor flow uses — suggestion checkboxes, live score recompute,
confirm writes accepted suggestions to the pool and moves resolved gaps,
cancel keeps the freshly scanned Match. The confirm copy is neutral
("Done"): this door never continues into a tailor run.

The review's semantics keep their single owner — [TAILOR-46]–[TAILOR-51]
are flow-agnostic and unchanged; this slice claims only the door, the
summary display, and the no-tailor-run delta ([PIPEBOARD-43]–[PIPEBOARD-48]).
Sharing the confirm-write path means form-only fallout in Tailor: the
private `TailorFlowStore.applyConfirmation` lifts into a reusable seam and
`MatchReviewView`'s hard-coded continue label becomes a parameter. No
TAILOR criteria change.

## Consequences

One review UX at every door, and the scan's proposals are never silently
discarded — the propose-confirm stance of docs/adr/0005 holds on demand as
it does mid-tailor. The section is offered whenever the trimmed job
description is non-empty, at any status, snapshot or not ([PIPEBOARD-45]'s
body carries that gate). If a future surface needs a summary-only display
(the CV preview stats ticket), it reads the persisted Match without this
door.
