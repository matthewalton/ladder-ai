---
key: CALSYNC
---

# Calendar Sync

The phase's accept-criterion slice: a calendar invite from a tracked company
surfaces as a proposed Stage with zero typing, and one confirmation later it
is on the board. Read-only EventKit access sits behind the
`CalendarSyncService` protocol with a fixture implementation (decisions/0001),
mirroring the `IntelligenceService` seam, so every criterion runs headlessly
with no calendar permission granted. The matching policy is decisions/0002,
the scan window and refresh triggers decisions/0003, dismissal memory
decisions/0004, and the stage-kind keyword guess decisions/0005.

Nothing is ever created silently (ARCHITECTURE.md §6): a scan only produces
proposals, and only the confirmation sheet turns a proposal into a Stage —
created new, or linked onto a Stage the user already tracks.

Out of scope: any write to the calendar (the entitlement posture is read-only,
decisions/0001), the per-Application timeline view (the timeline slice), email
parsing, and Phase 3+ capture behaviour.

## [CALSYNC-1] A calendar event from a tracked company surfaces as a proposed Stage

The tracer, and ROADMAP Phase 2 exit criterion 1: a fixture event whose title
contains a tracked Application's company name comes back from
`CalendarSyncStore.scan()` as a proposal for that Application — event
identifier, title, and schedule carried — with the user having typed nothing.
"Tracked" is defined by decisions/0002: status applied, active, or offer.

## [CALSYNC-2] A scan alone never creates a Stage

ARCHITECTURE.md §6 pinned as a criterion: after a scan over fixture events
that all match tracked Applications, the persisted Stage count is unchanged.
Only confirmation ([CALSYNC-8], [CALSYNC-9]) writes.

## [CALSYNC-3] An event matching no tracked Application yields no proposal

Covers both an unknown company and a known company whose Application is in a
non-tracked status (draft, rejected, withdrawn — decisions/0002). The scan
completes with an empty proposal list, not an error.

## [CALSYNC-4] An attendee email domain matching the company name proposes the event for that Application

The second matching signal (decisions/0002), for recruiter invites that never
name the company in the title: an attendee `jane@acme.com` matches an
Application whose normalised company name is `acme` ("Acme Corp" → `acme`).
Public mail domains are never company evidence — `gmail.com`, `outlook.com`
and friends are excluded by the deny-list in decisions/0002.

## [CALSYNC-5] Matching ignores case and punctuation in the company name

Normalised exact containment, no fuzzy distance (decisions/0002): an event
titled "ACME interview" matches company "Acme, Corp." — lowercase both, strip
punctuation, drop corporate suffixes (corp, inc, ltd, gmbh, …) per
decisions/0002, then substring-match. "Acme" never matches "Acmex".

## [CALSYNC-6] An event matching multiple Applications carries every match as a candidate on one proposal

One proposal per event, never one per match: two tracked Applications at the
same company yield a single proposal listing both as candidates, in board
order. The confirmation sheet renders the candidate picker — the picker UI
itself is visual-verify; the candidate list is the measurable clause.

## [CALSYNC-7] A recognised meeting link in the event becomes the proposal's meeting link

Detection is a pure helper over the event's location and notes text, location
first — Zoom, Meet, and Teams links are the recognised set. Recognised hosts: `zoom.us` (subdomains included), `meet.google.com`,
`teams.microsoft.com` / `teams.live.com`. An event with no recognised link is
still proposed — the meeting link is enrichment, not a gate — with a nil
meeting link.

## [CALSYNC-8] Confirming a proposal creates a pending Stage on the chosen Application

The Stage carries the confirmed kind, the event's start as `scheduledAt`, the
event identifier as `calendarEventID`, and the detected meeting link as
`meetingURL`; outcome starts pending. Creation goes through
`PipelineStore.addStage`, so the [PIPEBOARD-7] auto-advance (first Stage on an
applied Application → active) holds for calendar-born Stages too.

## [CALSYNC-9] Confirming a proposal against an existing Stage links the event to that Stage

The link path writes `calendarEventID`, `meetingURL`, and `scheduledAt` onto
the chosen existing Stage and creates nothing — Stage count unchanged, the
Stage's kind and outcome untouched.

## [CALSYNC-10] An event already linked to a Stage is not proposed again

Suppression by event identifier: once any Stage carries the event's
`calendarEventID`, later scans skip the event. Unlinked events at the same
company keep proposing.

## [CALSYNC-11] A dismissed event is not proposed on later scans

Dismissing a proposal records the event identifier (decisions/0004); the next
scan over the same fixture events omits it. Other events are unaffected.

## [CALSYNC-12] A dismissal survives an app relaunch

The round-trip persistence test CLAUDE.md requires for the slice's
`DismissedEvent` model: dismiss, close the store, reopen at the same URL —
the dismissal record is still there and the event still suppressed.

## [CALSYNC-13] The scan requests events from seven days back to thirty days ahead

decisions/0003. The store computes the window (as-of parameter for
determinism) and passes it to `CalendarSyncService.events(in:)`; the fixture
service captures the requested interval, the way [CVIMPORT-13] pins the
request rather than the vendor behind it. Seven days back keeps a
just-happened interview linkable.

## [CALSYNC-14] A calendar change notification triggers a fresh scan

decisions/0003: the store re-scans when the calendar-change signal fires —
`EKEventStoreChanged` in the live service, a test-postable notification
through the seam — plus the manual refresh action in the UI (the button is
visual-verify; the store's re-scan on signal is the measurable clause).

## [CALSYNC-15] A kind keyword in the event title pre-selects the proposal's stage kind

The keyword guess (decisions/0005) is a pure helper: "Acme phone screen" →
screen, "System design with Acme" → systemDesign, "Take-home review" →
takeHome, and so on per the map in decisions/0005. The confirmation sheet
starts from the guess and the user can change it before confirming.

## [CALSYNC-16] An event title with no kind keyword leaves the proposal's kind unselected

The guess never falls back to a default kind: no keyword → nil, and the
confirmation sheet requires a pick before it will confirm ([CALSYNC-8] always
has a kind).

## [CALSYNC-17] When calendar access is denied the scan reports the denied state

ROADMAP Phase 2 exit criterion 3: the store surfaces `.denied` instead of
proposals, throws nothing, and every other slice keeps working — the board
never depends on a scan having run. The UI renders a quiet one-line explainer
with a System Settings link (visual-verify).

## [CALSYNC-18] The app bundle carries the calendar full-access usage description

`NSCalendarsFullAccessUsageDescription` resolves non-empty from the bundle's
Info dictionary, with the permission-anxiety copy agreed in decisions/0001 —
reading requires the full-access tier, and the copy says what is read, that
nothing is written, and that nothing leaves the Mac.

## [CALSYNC-19] An empty scan with no tracked Application explains that matching starts past Draft

Case one of the silent empty scan (decisions/0006): no Application is
tracked, so `buildProposals` short-circuits and matching never ran — the bar
showed only its header and read as broken. The store exposes
`hasTrackedApplications`, computed live from the pipeline's Applications
against the tracked statuses (decisions/0002), and after an empty scan with
it false the bar renders the explainer:

> Nothing to match yet — matching starts once an application is past Draft.
> Move one along, or add one to the board.

The measurable clause is the store signal (`scanState == .ready`, zero
proposals, `hasTrackedApplications == false`); the rendered line is
visual-verify, like [CALSYNC-17]'s explainer. No explainer renders while
idle, scanning, or denied.

## [CALSYNC-20] An empty scan with tracked Applications explains that no event matched

Case two of the silent empty scan (decisions/0006): tracked Applications
exist but every event dropped out under the exact-match policy
(decisions/0002) — a real interview whose title spells the company
differently, or a recruiter invite from a public mail domain, yields nothing
and the bar went silent. After an empty scan with `hasTrackedApplications`
true the bar renders the explainer:

> No calendar events matched a tracked company — scans cover a week back and
> a month ahead.

The measurable clause is the store signal (`scanState == .ready`, zero
proposals, `hasTrackedApplications == true`) — the first direct coverage of
the tracked-but-unmatched path, which [CALSYNC-3]'s test reaches only via
non-tracked statuses. The rendered line is visual-verify.
