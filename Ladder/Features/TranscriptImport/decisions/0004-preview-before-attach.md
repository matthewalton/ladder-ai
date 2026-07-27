# 0004 — Nothing lands without a confirmed preview; the flow lives on the Stage detail

Status: accepted (agreed with the human at plan, 2026-07-20)

## Context

The attribution heuristic (decisions/0001) can be wrong, and the parse of
freeform pasted text can surprise. The app's standing pattern is that
derived data never lands silently: CV import has mandatory review, calendar
sync has the confirmation sheet. A direct-attach import would be the one
flow that writes unreviewed.

## Decision

Paste or drop opens a preview of the parsed segments — attribution,
timestamps, replacing indicator — and only confirming writes
([TRANSCRIPT-10], [TRANSCRIPT-13]). Both doors feed one parser
([TRANSCRIPT-11]). The import entry and the readout live on the Stage's
form sheet in the application detail — the closest thing the app has to a
Stage detail surface; a dedicated Stage detail view is not this slice's
job.

## Consequences

- A bad parse is caught before it persists; the readout never shows data
  the user hasn't seen.
- One more click per import than direct attach. Accepted: imports are
  rare (one per interview) and the pattern is house-wide.
- If a later slice builds a real Stage detail view, the readout moves with
  it — the derivation model is placement-agnostic.
