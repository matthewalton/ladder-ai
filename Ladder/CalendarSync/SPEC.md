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

The calendar-first path (decisions/0007) covers the reverse arrival order:
an interview already in the calendar with no Application yet on the board.
The interview heuristic flags such events as possible-interview proposals
([CALSYNC-21], [CALSYNC-22]), the check's other events are the fallback for
events it misses (decisions/0008: [CALSYNC-31], [CALSYNC-28]), confirmation
is the one gesture that creates the Application along with its Stage
([CALSYNC-26]), and the on-demand look-back scan reaches further into the
past for one application's company ([CALSYNC-29], [CALSYNC-30]).

Other events are ephemeral by design (decisions/0008): only a check — the
user-initiated scan — populates them ([CALSYNC-31]), automatic re-scans
leave them empty ([CALSYNC-32]), and closing the check-results sheet
discards them ([CALSYNC-33]). There is no standing browse surface.

The standing surface for proposals is the calendar section of the
Applications sidebar (decisions/0009): tracked applications first, a
divider, then every pending proposal ([CALSYNC-35]). The bar keeps the
check gesture and the explainers but never lists proposals ([CALSYNC-36]).

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

## [CALSYNC-4] An attendee email domain matching the company name proposes the event for that Application

The second matching signal (decisions/0002), for recruiter invites that never
name the company in the title: an attendee `jane@acme.com` matches an
Application whose normalised company name is `acme` ("Acme Corp" → `acme`).
Public mail domains are never company evidence — `gmail.com`, `outlook.com`
and friends are excluded by the deny-list in decisions/0002. Calendar and
scheduling infrastructure is excluded the same way: a Google-synced invite's
`unknownorganizer@calendar.google.com` is not evidence of Google, and a
Calendly notification is not evidence of Calendly.

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
tracked, so matching never ran — the bar showed only its header and read as
broken. (Since the calendar-first amendment the interview heuristic still
runs with an empty board; this explainer covers the scan that produced
nothing at all.) The store exposes
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
proposals, `hasTrackedApplications == true`) — direct coverage of the
tracked-but-unmatched path. The rendered line is visual-verify. Since the
calendar-first amendment, an unmatched event can still surface as a
possible-interview proposal ([CALSYNC-21], [CALSYNC-22]); this explainer
renders only when the scan produced nothing at all.

## [CALSYNC-21] An event matching no tracked Application whose title carries an interview keyword surfaces as a possible-interview proposal

The calendar-first half of the scan (decisions/0007): matching runs first and
wins — an event with candidates is a matched proposal, never a
possible-interview one. Only then does the interview heuristic look at the
leftovers. The keyword set is the heuristic vocabulary in decisions/0007:
the word "interview" plus every keyword the kind guess already knows
(decisions/0005) — so "Interview with Hooli" and "Acme phone screen"
both flag, and the kind guess pre-selects on the same title as ever.
A possible-interview proposal carries no candidates; dismissal works exactly
as [CALSYNC-11] — same `DismissedEvent` record, same suppression. This
amendment retires [CALSYNC-3]: its blanket promise — an unmatched event
yields no proposal — is now false by design, and [CALSYNC-23] carries the
narrower promise that survives. The number 3 stays retired.

## [CALSYNC-22] An event matching no tracked Application with a recognised meeting link surfaces as a possible-interview proposal

The heuristic's second signal, independent of the first: a recognised meeting
link ([CALSYNC-7]'s set — Zoom, Meet, Teams) flags the event even when the
title says nothing useful ("Chat with Sarah" + a Zoom link). Real interviews
titled without vocabulary are the case that motivated the browse fallback;
the link signal catches most of them one step earlier.

## [CALSYNC-23] An event matching no tracked Application with neither an interview keyword nor a recognised meeting link yields no proposal

The heuristic's negative space, keeping the calendar section quiet: dentist
appointments and team standups in the window stay invisible in the sidebar.
They remain reachable as a check's other events ([CALSYNC-31],
[CALSYNC-28]) — invisible is not gone.

## [CALSYNC-24] The company guess takes the registrable-domain label of a non-public attendee or organizer email

The pre-fill for the confirmation sheet's company field (decisions/0007):
`recruiting@waynetech.com` → `waynetech`, using the same
registrable-domain and deny-list rules as [CALSYNC-4]
(`CalendarMatcher.companyLabel`) — public providers and calendar
infrastructure (`calendar.google.com`, `calendly.com`) both fall through
to the title fallback ([CALSYNC-25]). When the label appears in the event title
as a word, the guess takes the title's casing — "Interview with WayneTech"
turns the label into "WayneTech". A guess only ever pre-fills — the field
stays editable, the [CALSYNC-15] stance.

## [CALSYNC-25] With no usable email domain the company guess falls back to the event title stripped of interview vocabulary

The no-email case: no attendee emails beyond the user's own, so the title is
all there is. Strip the heuristic vocabulary (decisions/0007) and connective
words from the title; what remains, in title order and casing, is the guess —
"Interview with Hooli" → "Hooli". Nothing left → empty field, the
user types. Both guess criteria are pure-helper testable, no EventKit.

## [CALSYNC-26] Confirming a possible-interview proposal creates an applied Application and its event-linked Stage

The one new write path, still one gesture behind the confirmation sheet
(ARCHITECTURE.md §6). The sheet collects company (pre-filled by the guess,
editable) and role title (free text — the calendar knows nothing useful);
blank either → the store refuses, nothing created. Creation goes through
`PipelineStore.createApplication` (status applied, `appliedAt` = the event's
start as the best evidence on hand — the real application predates the
interview, and the date is editable like any manual add) then
`PipelineStore.addStage` with the confirmed kind, the event identifier, and
the detected meeting link — so the [PIPEBOARD-7] auto-advance carries the new
Application straight to active, mirroring [CALSYNC-8].

## [CALSYNC-28] Picking an other event yields a proposal for that event

The escape hatch that makes the heuristic safe to keep small: any of a
check's other events can become a proposal on demand — with candidates when
matching finds tracked Applications ([CALSYNC-6] semantics), as a
possible-interview proposal when it does not, heuristic verdict ignored.
From there the normal confirmation flow runs: [CALSYNC-8]/[CALSYNC-9] on
candidates, [CALSYNC-26] without. (Reworded from "browsed event" when
decisions/0008 replaced the browse list with the check's other events — the
promise, pick → proposal, is unchanged.)

## [CALSYNC-29] A look-back scan requests events from ninety days back to the scan instant

The on-demand deep window (decisions/0007; ninety days was defaulted at
plan, not agreed — the number lives in one place). A per-application action,
never automatic and never the standing window: [CALSYNC-13]'s seven-back /
thirty-ahead stands untouched (decisions/0003). Pinned at the seam the
[CALSYNC-13] way — the fixture service captures the requested interval.

## [CALSYNC-30] A look-back scan proposes only events matching its application's company

The scope that keeps ninety days of calendar from flooding the calendar
section: the
look-back matches against exactly one company — the application the action
was invoked on — with the same matching policy (decisions/0002) and the same
linked/dismissed suppression. Every proposal it emits carries that
application as the sole candidate, so confirmation lands on it: [CALSYNC-8]
to create a Stage there, [CALSYNC-9] to link an existing one.

## [CALSYNC-31] A check lists every fetched event without a proposal as an other event

The fallback surface after decisions/0008 retired the standing browse list
([CALSYNC-27]): a check — the user-initiated scan — keeps the events that
produced no proposal as its other events, in start order. Linked
([CALSYNC-10]), dismissed ([CALSYNC-11]), and proposed events are all
excluded — a proposal already surfaces above, never twice. Store state
computed from the same fetched events as the scan, no second fetch, never
persisted to disk. Presentation is the check-results sheet (decisions/0008):
proposals prominent on top, other events beneath in a collapsed "Other
events (N)" disclosure — the sheet layout and the removal of the bar's
standing "Browse events" button are visual-verify; the list's contents and
population are the measurable clause.

## [CALSYNC-32] An automatic re-scan leaves the other-events list empty

The user-check-only half of decisions/0008: the calendar-change signal
([CALSYNC-14]) and an already-granted launch scan refresh proposals as ever
but populate no other events — after such a scan the store's other events
are empty even when unproposed events sit in the window. Only a check
([CALSYNC-31]) fills the list, so it never reappears unless the user chooses
to check again.

## [CALSYNC-33] Closing the check-results sheet discards the other events

The ephemerality gesture (decisions/0008): ending the review empties the
store's other events — the calendar section afterwards shows proposals
only, and the list only comes back with the next check. The measurable
clause is the store's discard; the sheet's close wiring is visual-verify.

## [CALSYNC-34] The other-events filter narrows the list to events whose title contains the typed text

The known-interview escape (decisions/0008): the expanded disclosure carries
a filter field; "hooli" keeps "Interview with Hooli" and drops "Team
standup". Containment ignores case; an empty filter shows the whole list.
Pure filtering over the other events, testable with no UI — the field
itself is visual-verify.

## [CALSYNC-35] The calendar section derives one sidebar row per pending proposal

The proposals' standing surface after decisions/0009: the calendar section —
the Applications sidebar beneath the tracked-applications list, separated
by a divider — lists every pending proposal, matched and possible-interview
alike, in scan order. The measurable clause is the section model, a pure
helper over the store's proposals: one row per proposal carrying the event
title, its start, and either the possible-interview flag or the kind guess;
zero proposals → no section at all, so the divider never renders alone and
the sidebar reads as it did before the slice existed. The sidebar rendering
of those rows is visual-verify. Interaction is compact for the narrow
surface: clicking a row opens the confirmation sheet, and dismissal is a
hover ✕ and a right-click context menu — both through
`CalendarSyncStore.dismiss`, so suppression and its persistence stay
[CALSYNC-11] and [CALSYNC-12].

## [CALSYNC-36] The bar renders only its header row and the explainers

The flip side of [CALSYNC-35] (decisions/0009): the bar never lists
proposals again. It keeps the "From your calendar" header, the "Check
calendar" control — still the explicit gesture that first requests calendar
access (decisions/0008) — and the explainers ([CALSYNC-17], [CALSYNC-19],
[CALSYNC-20]), whose store signals stay the measurable clauses they were.
With proposals pending and no explainer state active the bar shows its
header row alone; the constant-height strip is visual-verify.
