# 0001 — Read-only calendar access behind a seam; full-access entitlement

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

The slice reads EventKit, which needs a permission grant, an entitlement, and
a usage string — none of which can exist in headless CI, and ROADMAP Phase 2
exit criteria demand the suite green with no calendar permission granted and
the app fully usable when access is denied. The repo already has the shape
for this: all LLM access sits behind `IntelligenceService` with a fixture
implementation.

## Decision

All calendar access goes through a `CalendarSyncService` protocol: report the
authorisation state, request access, and return lightweight value-type events
(`CalendarEvent`: identifier, title, start, location, notes, attendee
addresses, organizer) for a date interval — no `EKEvent` crosses the seam. A
`FixtureCalendarSyncService` serves in-code canned events to tests and
previews; `EventKitCalendarSyncService` is the live implementation, exercised
by humans only.

The posture is read-only: the service exposes no write operation, the app
never mutates the calendar. Reading still requires the *full-access* tier
(macOS has no read-only tier — write-only is the lesser grant, useless here),
so `project.yml` gains `Ladder.entitlements` with
`com.apple.security.personal-information.calendars` (hardened runtime is
already on) and `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription` with
permission-anxiety copy:

> Ladder looks for interviews for jobs you're tracking — nothing more. It
> only reads: no event is ever added or changed, and nothing about your
> calendar leaves this Mac.

Denied access is a state, not an error: the scan reports it, the UI explains
it quietly, and every other slice works untouched.

## Consequences

- Every criterion runs headlessly against the fixture service; no test may
  construct an `EKEventStore` ([CALSYNC-17], AGENTS.md).
- The seam is the testable surface for the scan window ([CALSYNC-13]) and the
  change signal ([CALSYNC-14]).
- The usage description is pinned by [CALSYNC-18]; the entitlement itself is
  build configuration, verified by the human permission flow.
