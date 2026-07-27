# 0001 — Attribution by label heuristic, no speaker picking

Status: accepted (agreed with the human at plan, 2026-07-20)

## Context

Native capture attributed speakers by stream identity (mic = me, system =
them). Imported text has only the labels Granola printed. Something must
map labels to the two-valued attribution the downstream models expect, and
a per-import "which speaker is you?" step would tax every single import.

## Decision

A trimmed, case-insensitive speaker label of "Me" attributes `.me`; any
other label — "Them", a name, "Interviewer" — attributes `.them`. Granola
labels the mic side "Me", so its exports map with zero typing. Labels are
consumed, not stored: `Segment` carries only the attribution.

## Consequences

- [TRANSCRIPT-5] and [TRANSCRIPT-6] pin the rule; the parser needs no UI.
- An export using the user's real name instead of "Me" mis-attributes
  everything to `.them`. Accepted: the preview ([TRANSCRIPT-10]) shows the
  attribution before anything lands, and the fix is editing the paste and
  re-importing — cheaper than a picker on every import.
- If a future Granola format breaks the rule, the heuristic grows here, not
  in per-import UI.
