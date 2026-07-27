# 0003 — Elapsed copy is spelled out, matching the board card

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

The ticket's examples used compact units ("5d to hear back", "in stage 3d"),
but the shipped board card already spells its footer out ("12 days on
trail", [PIPEBOARD-16]), and DESIGN.md §8 sets a sentence-case, plain-verb
voice for functional copy. The two styles could not both stand.

## Decision

Every elapsed annotation is spelled out: "5 days to hear back", "3 days",
"1 day", "same day" on segments ([TIMELINE-7]); "In stage 3 days" /
"In stage today" as the trailing in-stage label ([TIMELINE-9]). Digits
render monospaced per DESIGN.md §2. Compact unit forms ("5d") do not appear
anywhere in the slice.

## Consequences

- Timeline copy and board-card copy read as one voice.
- Whole-day arithmetic reuses the [PIPEBOARD-16] floor (86 400-second
  days), so the same elapsed time never reads differently on card and
  timeline.
- Localisation later touches strings, not layout — spelled-out copy leaves
  room for it.
