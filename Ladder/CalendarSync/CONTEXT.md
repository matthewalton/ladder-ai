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

**Explainer**:
The quiet one-line message the bar renders below its header when there is
nothing to show — one for the denied state ([CALSYNC-17]) and one per empty
scan case ([CALSYNC-19], [CALSYNC-20]).
_Avoid_: hint, placeholder, error message
