# 0004 — Dismissals persist in a slice-owned SwiftData model, keyed by event identifier

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

A proposal the user declined must not return on the next scan — re-proposing
the same event every refresh turns the feature into a nag. Session-only
memory forgets on relaunch; no memory at all re-asks every scan.

## Decision

A `DismissedEvent` SwiftData model — the slice's own, registered alongside
the shared schema — stores the dismissed event's `calendarEventID` and the
dismissal date. The scan filters proposals against it, the same way it
filters events already linked to a Stage. Dismissal is per event, forever:
no snooze tier, no expiry, and a changed event (new time, new title) stays
dismissed — the identifier is the identity.

## Consequences

- [CALSYNC-11] pins the suppression, [CALSYNC-12] the round-trip (the
  persistence test CLAUDE.md requires for any model change).
- Rows are tiny and unbounded growth is bounded by the user's own calendar;
  no cleanup pass needed.
- Un-dismissing has no UI in this slice; if wanted later it is a new
  criterion, not a schema change.
