# 0002 — Timestamps are optional; nothing is invented

Status: accepted (agreed with the human at plan, 2026-07-20)

## Context

ARCHITECTURE.md §3 gives `Segment` start/end times and the roadmap calls
the Stage-detail view a "timestamped readout" — but the common Granola
copy-paste carries no per-segment timestamps at all. Requiring them would
reject the primary input; fabricating them (index-spaced, zeroed) would put
false data in front of Phase 4's debrief.

## Decision

`Segment.tStart`/`tEnd` are optional. They parse when the text carries them
([TRANSCRIPT-8]) and stay nil when it does not. The readout shows timestamp
labels exactly for segments that have them ([TRANSCRIPT-18]) and falls back
to sequence order with no time column otherwise ([TRANSCRIPT-19]).
`durationSec` derives from the last timestamp present, else 0.

## Consequences

- The common untimestamped paste imports cleanly; a timestamped export gets
  the full readout with no extra work.
- Downstream consumers (Phase 4 debrief) must treat segment times as
  optional — order is the only guaranteed structure.
- A `durationSec` of 0 means "unknown", not "instant"; no view renders it
  as a length.
