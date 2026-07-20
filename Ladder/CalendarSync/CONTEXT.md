# Calendar Sync — language

Slice-local terms. `Application`, `Stage`, and `Profile` are defined in the
root `CONTEXT.md`; `Stage kind` and `Stage outcome` in
`Ladder/PipelineBoard/CONTEXT.md`. None is restated here.

**Scan**:
One pass over the calendar window: fetch events through `CalendarSyncService`,
filter to matches, suppress linked and dismissed events, emit proposals.
_Avoid_: sync (the slice never writes back), import, poll

**Proposal**:
One scanned event proposed to the user: the event's identity, schedule,
candidates, detected meeting link, and kind guess. Exists only in the store's
state — never persisted; only confirmation writes.
_Avoid_: suggestion, match (that word is the predicate, not the object),
pending stage

**Candidate**:
A tracked Application a proposal could attach to. One candidate confirms
directly; several put a picker in the confirmation sheet.
_Avoid_: option, target

**Tracked Application**:
An Application whose status is applied, active, or offer — the ones a calendar
event can match (decisions/0002).
_Avoid_: open application, live application

**Meeting link**:
The Zoom/Meet/Teams URL detected in an event's location or notes, carried onto
the proposal and the confirmed Stage's `meetingURL`.
_Avoid_: call link, video link, conference URL

**Kind guess**:
The stage kind pre-selected from a keyword in the event title (decisions/0005).
A guess only ever pre-selects — the user confirms or changes it.
_Avoid_: inference, auto-detect, classification

**Confirmation**:
The one gesture that writes: turning a proposal into a new pending Stage, or
linking it onto an existing Stage. Happens in the confirmation sheet, never
silently (ARCHITECTURE.md §6).
_Avoid_: accept, approve, apply

**Dismissal**:
Declining a proposal. Persisted by event identifier (`DismissedEvent`,
decisions/0004) so the event never comes back.
_Avoid_: ignore, snooze (nothing comes back later), reject (that word belongs
to Application status)

**Denied state**:
The scan outcome when calendar access is refused: no proposals, no error, the
rest of the app untouched (decisions/0001).
_Avoid_: permission error, failure

**Empty scan**:
A scan that completes (`.ready`) with zero proposals. Not the denied state —
access was granted and the pass ran; there was simply nothing to propose.
_Avoid_: failed scan, no results, empty state

**Bar**:
The slim strip above the board carrying the "From your calendar" header,
the check control, and the explainers — never proposals (decisions/0009).
_Avoid_: banner, overlay, proposals bar

**Calendar section**:
The proposals' standing surface (decisions/0009): the area of the
Applications sidebar beneath the tracked-applications list, separated by a
divider, listing every pending proposal as a compact row. Absent entirely
when no proposal is pending.
_Avoid_: proposals list, inbox, tray, sidebar section

**Explainer**:
The quiet one-line message the bar renders below its header when there is
nothing to show — one for the denied state ([CALSYNC-17]) and one per empty
scan case ([CALSYNC-19], [CALSYNC-20]).
_Avoid_: hint, placeholder, error message

**Interview heuristic**:
The flag over events matching no tracked Application: a title keyword (the
word "interview" plus the decisions/0005 kind vocabulary) or a recognised
meeting link (decisions/0007). Flags only — never creates, never matches.
_Avoid_: classifier, detection, smart scan

**Possible-interview proposal**:
A proposal for an event matching no tracked Application, flagged by the
interview heuristic or picked from the other events. Carries no candidates;
its confirmation creates ([CALSYNC-26]) instead of attaching.
_Avoid_: unmatched proposal, orphan event, suggestion

**Company guess**:
The pre-fill for the confirmation sheet's company field: attendee/organizer
email domain first, event title stripped of interview vocabulary as the
fallback (decisions/0007). Like the kind guess, it only ever pre-fills.
_Avoid_: auto-fill, company detection, inference

**Check**:
The user-initiated scan — pressing "Check calendar". The only scan that
populates other events (decisions/0008); automatic re-scans refresh
proposals alone.
_Avoid_: browse, manual refresh, sync

**Other events**:
A check's fetched events that produced no proposal — linked, dismissed, and
proposed events excluded. The fallback surface when the interview heuristic
misses a real interview; picking one turns it into a proposal on demand
([CALSYNC-28]). Ephemeral: never persisted, emptied by automatic re-scans
and by closing the check-results sheet.
_Avoid_: browse list (the pre-0008 standing surface), event picker,
calendar view, all events

**Check-results sheet**:
The sheet a check presents when its scan completes: proposals prominent on
top, other events beneath in a collapsed disclosure with a title filter.
Closing it discards the other events.
_Avoid_: browse events sheet, results dialog, review sheet (the confirmation
sheet already owns "review")

**Look-back scan**:
The on-demand per-application scan reaching ninety days back
(decisions/0007), matched against that application's company only. Never
automatic, never the standing window.
_Avoid_: backfill, deep scan, history import
