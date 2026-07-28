# 0006 — An indicator row proves its content, it does not just announce it

**Status:** accepted (2026-07-28)

Amends docs/adr/0003.

## Context

Ticket #201: after importing a job description PDF, the application detail's
Job Description section looked empty. It was not — the JD was stored, and
every gate keyed off it fired, which is why Create CV was offered and the
export succeeded. What the user saw was the docs/adr/0003 collapse: the
section swapped its editor for a row reading "Job description set", and that
row reads as a status flag rather than as "your posting is in here".

The pattern already had the answer inside it. Generated and imported content
carries a provenance detail in its label — "Debrief generated — 24 Jul 2026",
"Prep pack generated — 24 Jul 2026", "Notes attached — 22 Jul 2026". The three
fields the user types or imports into — the job description and notes on the
application detail, the prep context on the Stage form — were the only
collapsed surfaces whose label carried nothing but the fact of being set.

Two questions were put to the human at the plan stage and both were settled.
Collapsing at any set content stands: a length threshold would return variable
form height, which is the scrolling that 0003 existed to stop, and the
imported-PDF case that raised the ticket is long enough to collapse under any
threshold worth setting. Scope is the three typed-or-imported fields, matching
the "Long-text field" term exactly.

## Decision

- **A collapsed row identifies its content, not merely its presence.** For the
  three typed-or-imported long-text fields, the row shows the start of the
  content and its size. Both: the snippet answers "is this the right posting",
  the size answers "how much is in there", and neither answers the other.
- **Generated content keeps its date.** Debrief, prep pack and Granola notes
  already identify themselves the way that suits them — when they were made is
  the fact that matters about a generated artefact, and a snippet of an LLM
  debrief proves less than its date does. They are untouched.
- **Collapse still happens at any set content**, decided at appearance, with
  whitespace-only counting as not set. docs/adr/0003 is unchanged on this
  point; only what the row then shows is amended.
- **The read-only window's affordance reads "View".** The job description's
  window never edits (0003), so "Open" overstated it; the editable windows —
  notes, prep context — keep "Open".
- The snippet and size are derived by a pure helper beside the existing
  collapse helper, so the rule is testable without views.

## Consequences

- PIPEBOARD's [PIPEBOARD-29] is amended: the row named the content, it now
  identifies it. The shared `IndicatorRow` in `Ladder/Shared/DesignSystem/`
  grows an optional detail line and a configurable open-affordance label;
  both default to today's behaviour, so DEBRIEF, PREP and TRANSCRIPT call
  sites are untouched.
- The root `CONTEXT.md` **Indicator row** term is sharpened accordingly.
- A JD whose extraction opened with page furniture will show that furniture as
  its snippet. That is a true report of what was stored, and the fix belongs to
  extraction ([PIPEBOARD-26]–[PIPEBOARD-28]), not to the row.
