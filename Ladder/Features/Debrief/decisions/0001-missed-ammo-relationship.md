# 0001 — Missed ammo is a SwiftData relationship, referenced by payload index

Status: accepted (agreed with the human, 2026-07-20).

## Context

Missed ammo must point back at Profile Achievements — "the stronger
Achievement is on file" (root CONTEXT.md) is the product's whole point.
But `Achievement` has no stable string id: it carries user-owned `text`
(editable at any time, [PROFILE-9]), a `sortIndex`, and SwiftData identity
only. Storing text copies breaks silently when the user rewords the canon;
adding a UUID means amending the Profile slice's model and a migration for
another slice's benefit.

## Decision

`DebriefQuestion` is a `@Model` with a real `missedAmmo: [Achievement]`
relationship — question entries are model rows, not `Codable` value
structs, precisely so this relationship can exist.

The service protocol references achievements by **payload index**: the
request payload lists the Profile's achievements with stable zero-based
indices, the response names indices, and the store maps each index back to
the Achievement object it listed at validation time. An index matching
nothing fails validation and feeds the repair path — the [TAILOR-8]
stance.

## Consequences

- Missed-ammo links survive rewording of the canon; deleting an
  Achievement drops it from `missedAmmo` rather than dangling.
- ARCHITECTURE.md §3's `QAItem` value shape is realised as the
  `DebriefQuestion` model class; the documented fields are all present.
- The payload index is a per-request wire protocol, never persisted —
  nothing outside one generate run depends on achievement order.
- The relationship never cascades toward the Profile: deleting a Stage or
  Debrief leaves Achievements untouched ([DEBRIEF-3]).
