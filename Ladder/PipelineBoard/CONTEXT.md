# Pipeline Board — language

Slice-local terms. `Application`, `Stage`, and `Profile` are defined in the
root `CONTEXT.md`; `CV snapshot` in `Ladder/CVExport/CONTEXT.md`. None is
restated here. Trail vocabulary stays narrative-only (root CONTEXT.md): "next
waypoint" and "days on trail" appear as card footer text per DESIGN.md §6,
never as code identifiers.

**Board**:
The applications view: one column per `ApplicationStatus`, every Application
appearing in the column matching its status, cards draggable between columns
along legal transitions.
_Avoid_: kanban, pipeline view, tracker

**Column**:
One status's lane on the board — all six render, empty ones included.
_Avoid_: lane, swimlane, bucket

**Transition map**:
The fixed set of legal status moves (decisions/0003). A move outside the map
is refused by the store; the board only offers legal drop targets.
_Avoid_: workflow, state machine, lifecycle rules

**Auto-advance**:
The one status change the store makes on the user's behalf: the first Stage
added to an applied Application advances it to active (decisions/0003).
_Avoid_: auto-transition, promotion

**Backfill**:
The idempotent load-time pass that gives Phase 1 applied Applications their
missing `appliedAt` from `createdAt`.
_Avoid_: migration script, data fix, repair

**Manual add**:
Creating an Application from the board's add form rather than a CV export
(decisions/0004) — the one creation path that attaches no CV.
_Avoid_: quick add, manual entry, new application flow

**Stage kind**:
What sort of step a Stage is — a known kind (screen, recruiter, technical,
system design, take-home, behavioral, final, offer) or a free-text other.
Persisted as a raw string (decisions/0002).
_Avoid_: stage type, interview type, category

**Stage outcome**:
How a Stage resolved: pending, passed, failed, or no response.
_Avoid_: result, verdict, status (that word belongs to the Application)

**Next waypoint**:
The card's narrative label for the earliest pending Stage — footer text only,
per DESIGN.md §6.
_Avoid_: next step, upcoming stage (in UI copy); any use as a code identifier

**JD import**:
Attaching a job description to an existing Application by extracting text
on-device from a dropped PDF or docx file (decisions/0005) or from a pasted
link's fetched page (decisions/0006). The text lands raw and editable — no
LLM cleanup, no structuring.
_Avoid_: JD upload, JD parsing, scraping

**Days on trail**:
The card's narrative label for whole days elapsed since `appliedAt ??
createdAt`.
_Avoid_: age, elapsed time (in UI copy); any use as a code identifier
