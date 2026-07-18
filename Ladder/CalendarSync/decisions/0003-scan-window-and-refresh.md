# 0003 — Scan window 7 days back / 30 ahead; refresh on change signal + manual

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

The scan needs bounds — a whole-calendar sweep is slow and proposes ancient
noise — and a trigger. EventKit posts `EKEventStoreChanged` on any calendar
mutation; the alternative was timer polling.

## Decision

The store computes the window — seven days back to thirty days ahead of an
as-of instant passed in for test determinism — and hands it to
`CalendarSyncService.events(in:)`. Seven days back keeps a just-happened
interview linkable to its Stage; thirty ahead covers any realistically
scheduled round.

Refresh is signal-driven plus manual, no timers: the live service surfaces
`EKEventStoreChanged` through the seam as a service-agnostic change signal
the store subscribes to (test-postable without EventKit); the UI keeps an
explicit refresh action. Scans triggered while one is in flight coalesce —
last signal wins, no queue.

## Consequences

- [CALSYNC-13] pins the requested interval at the seam; [CALSYNC-14] pins
  the re-scan on signal.
- No background wake-ups when the calendar is quiet; a stale view costs at
  most one manual refresh.
- The window is fixed in code, not settings — revisit only with evidence.
