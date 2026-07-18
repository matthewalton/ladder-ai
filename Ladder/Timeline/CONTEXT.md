# Timeline — language

Slice-local terms. `Application`, `Stage`, and `Profile` are defined in the
root `CONTEXT.md`; `stage kind` and `stage outcome` in
`Ladder/PipelineBoard/CONTEXT.md`. None is restated here. Trail vocabulary
stays narrative-only (root CONTEXT.md): the Phase 5 journey words (waypoint,
base camp, summit) never name anything in this slice's code or functional
copy.

**Timeline**:
The read-only per-Application vertical view: applied → heard back → each
Stage → outcome, entries joined by segments carrying elapsed labels. The
everyday, utilitarian sibling of the Phase 5 Summit View (DESIGN.md §6).
_Avoid_: journey view, history, activity feed

**Entry**:
One node on the line — the applied entry, the heard-back entry, a Stage
entry, or the outcome entry. Rendered as a trail blaze, filled or hollow.
_Avoid_: node, waypoint, milestone, event (that word belongs to calendar-sync)

**Heard back**:
The derived first-response moment: the earliest date across the
Application's Stages' `scheduledAt` and `heardBackAt` (decisions/0001).
Never stored on Application.
_Avoid_: first response, replied, contact date

**Outcome entry**:
The closing entry a terminal Application ends with, naming its status —
Offer, Rejected, or Withdrawn.
_Avoid_: result, verdict, terminus

**Segment**:
The stretch of line between two adjacent entries; carries the elapsed label
when both ends are dated.
_Avoid_: gap, interval, edge

**Elapsed label**:
A segment's spelled-out whole-day annotation — "5 days to hear back",
"3 days", "1 day", "same day" (decisions/0003). Monospaced digits per
DESIGN.md §2.
_Avoid_: duration, timer; compact forms like "5d"

**In-stage label**:
The trailing annotation on a non-terminal timeline: whole days since the
latest dated entry — "In stage 3 days", "In stage today".
_Avoid_: current stage timer, time in stage

**Trail blaze**:
The stage-kind marker Shape set in `Ladder/Shared/DesignSystem/` — circle,
diamond, square, double-chevron, flag — each drawable filled or hollow
(decisions/0002). The one icon language shared by board, timeline, and the
later Summit View (DESIGN.md §5).
_Avoid_: icon, badge, glyph, marker

**Content toggle**:
The pipeline shell's toolbar switch swapping the content pane between the
board and the selected Application's timeline (DESIGN.md §4).
_Avoid_: tab, mode picker, view switcher
