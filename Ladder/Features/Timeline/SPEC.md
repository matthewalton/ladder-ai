---
key: TIMELINE
---

# Timeline

The third Phase 2 slice: a read-only vertical timeline per Application —
applied → heard back → each Stage → outcome — with elapsed-time annotations
on the segments between entries. Pure presentation over data pipeline-board
and calendar-sync already persist: this slice writes nothing and changes no
model (decisions/0001). It also introduces the trail-blaze Shape set in
`Ladder/Shared/DesignSystem/` (decisions/0002) — the timeline is its first
consumer; the board and the Phase 5 Summit View adopt it later.

Derivations live in `TimelineModel` statics taking an `asOf` date, the
[PIPEBOARD-16] pattern, so tests are deterministic and the view stays thin.
DESIGN.md §6 fixes the look — vertical `pine` line, blazes as nodes, hollow
future / filled completed, monospaced digits — and the look is visual-verify;
the criteria below claim the derivations behind it.

Out of scope: any write path or model change (Stage `heardBackAt` is edited
in pipeline-board's stage form; calendar-sync links events), board and
transition behaviour (PIPEBOARD), Summit View decoration and contour texture
(Phase 5), and the gated `prepPack`/`transcript`/`debrief` models.

## [TIMELINE-1] The timeline for an applied Application begins with its applied entry

The tracer: fixture tailor run → export on an in-memory store → derive the
timeline. The first entry is the applied entry, dated `appliedAt`. A draft
Application (`appliedAt == nil` before backfill ever sees it) has no applied
entry — the timeline starts at whatever entries its Stages provide. Proves
the derivation seam, the entry model, and the store read in one line.

## [TIMELINE-2] The heard-back entry carries the earliest date across the Application's Stages

Derived, never stored (decisions/0001): the minimum over every Stage's
`scheduledAt` and `heardBackAt`. The entry sits between the applied entry and
the Stage entries regardless of how that date compares to `appliedAt`.

Edge cases:

- Stage A `scheduledAt` Jul 10 with `heardBackAt` Jul 8, Stage B `scheduledAt`
  Jul 6 → heard back Jul 6: the minimum ranges over both fields of every
  Stage, not just the first Stage.

## [TIMELINE-3] An Application whose Stages carry no dates has no heard-back entry

Zero Stages, or Stages whose `scheduledAt` and `heardBackAt` are all nil:
there is nothing to derive from, so the entry is absent — never a placeholder
or an undated row.

## [TIMELINE-4] Stage entries follow the Stage chain's added order

One entry per Stage, ordered by `sortIndex` (the `orderedStages` order), not
by date — an undated Stage keeps its place in the chain.

## [TIMELINE-5] A terminal Application's timeline ends with its outcome entry

Terminal means `offer`, `rejected`, or `withdrawn`. The outcome entry is the
last entry and names the status ("Offer", "Rejected", "Withdrawn" — functional
copy, sentence case).

## [TIMELINE-6] A non-terminal Application's timeline has no outcome entry

`draft`, `applied`, and `active` Applications end with their Stage entries
(or earlier); the outcome entry only exists once the trail is closed.

## [TIMELINE-7] A segment between two dated entries is labeled with the whole days elapsed between them

Whole days floor over 86 400-second days, the [PIPEBOARD-16] arithmetic.
Copy is spelled out (decisions/0003): the applied → heard-back segment reads
"5 days to hear back"; every other segment reads "3 days". Singular "1 day";
two entries on the same calendar day read "same day".

Edge cases:

- applied Jul 1 09:00 → heard back Jul 6 08:00 → "4 days to hear back": the
  floor counts completed 24-hour days, not calendar-date differences.

## [TIMELINE-8] A segment touching an undated entry carries no elapsed label

An undated Stage entry breaks the arithmetic on both sides: the segments
into and out of it render as plain line, never "0 days" or a guess.

## [TIMELINE-9] A non-terminal Application's in-stage label counts whole days since its latest dated entry

The trailing annotation under the last entry: "In stage 3 days" ("In stage
1 day"; under one whole day, "In stage today"), measured from the latest
dated entry to `asOf`. Absent when no entry carries a date, and absent on
terminal Applications — the outcome entry ends their line ([TIMELINE-5]).

## [TIMELINE-10] A Stage entry is filled exactly when its outcome is resolved

Resolved means `passed`, `failed`, or `noResponse`; a `pending` Stage renders
hollow (DESIGN.md §6 "future stages hollow, completed filled"). The applied,
heard-back, and outcome entries are always filled — they only exist because
their moment happened.

## [TIMELINE-11] Each stage kind renders its designated trail blaze

The DESIGN.md §5 assignments — circle = screen, diamond = technical,
square = behavioral, double-chevron = final, flag = offer — extended over the
full kind set by family: recruiter joins screen on circle;
system design and take-home join technical on diamond; `.other` kinds take
circle, the neutral default. The mapping is a total function on `StageKind`;
the Shape set itself lives in `Ladder/Shared/DesignSystem/` (decisions/0002).

## [TIMELINE-12] The content pane switches between the board and the selected Application's timeline

The [PIPEBOARD-14] pattern: a toolbar toggle in the pipeline shell swaps the
content pane between the board and the selected Application's timeline
(DESIGN.md §4 "content (Stage timeline or board)"). The measurable clause is
that both content roots render for a selected Application; toggle chrome,
and the toggle disabling with no selection, are visual-verify.
