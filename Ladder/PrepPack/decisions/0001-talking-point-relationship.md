# 0001 — Talking points are model rows with an Achievement relationship, referenced by payload index

Status: accepted (agreed with the human, 2026-07-20, at the plan stage).

## Context

Talking points must point back at Profile Achievements — the pack's value
is "here is what to say, and here is the career history behind it".
ARCHITECTURE.md §3 sketches `talkingPoints: [String]` "mapped to
Achievement ids", but `Achievement` has no stable string id, and the
debrief slice already faced this exact shape: stored text copies break
silently when the user rewords the canon, and adding a UUID means amending
the Profile slice for another slice's benefit (Debrief decisions/0001).

## Decision

`PrepTalkingPoint` is a `@Model` with a real
`achievements: [Achievement]` relationship — talking points are model
rows, not `Codable` value structs, precisely so this relationship can
exist. The Debrief slice's protocol is reused unchanged: the request
payload lists the Profile's achievements with stable zero-based indices,
the response names indices per talking point, and the store maps each
index back to the Achievement object it listed at validation time. An
index matching nothing fails validation and feeds the repair path — the
[TAILOR-8] stance.

Mock tasks, by contrast, reference nothing: they stay `Codable` value
structs (`MockTask`: title, brief) embedded on the pack.

## Consequences

- Talking-point links survive rewording of the canon; deleting an
  Achievement drops it from the talking point rather than dangling.
- ARCHITECTURE.md §3's `talkingPoints: [String]` + "Achievement ids"
  phrasing is superseded, exactly as Debrief decisions/0001 superseded
  `QAItem`.
- The payload index is a per-request wire protocol, never persisted —
  nothing outside one generate run depends on achievement order.
- The relationship never cascades toward the Profile: deleting a Stage or
  PrepPack leaves Achievements untouched ([PREP-3]).
