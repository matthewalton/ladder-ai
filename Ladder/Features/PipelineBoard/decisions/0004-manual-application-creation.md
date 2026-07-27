# 0004 — Manual add: the board's own creation path

Status: accepted (agreed with the human, 2026-07-18)

## Context

Until now the only way an Application existed was cv-export's export
([CVEXPORT-10]) — heavy when the goal is just tracking, and it made
calendar-sync untestable by hand: the scan only matches Applications past
draft (CalendarSync decisions/0002), and nothing could create one without
running a full tailor → export. Nothing could create a `.draft` Application
at all.

## Decision

The board owns a second creation path, the manual add:

- A store seam, `PipelineStore.createApplication`, so the rules live beside
  the transition map and tests hit the store.
- The form offers a Draft-or-Applied choice. Applied takes an "Applied on"
  date defaulting to today, backdating allowed, stored as `appliedAt`
  ([PIPEBOARD-17]); Draft leaves `appliedAt` nil for the draft → applied
  stamp to fill later ([PIPEBOARD-18], decisions/0003).
- Fields: company and role title required — blank refused ([PIPEBOARD-19]) —
  source and notes optional. `jobDescription` stays empty and no
  `cvSnapshot`/`cvSelectionRationale` is ever fabricated: export remains the
  only path that attaches a CV.
- No dedup, the [CVEXPORT-13] stance: the same company and role twice is two
  Applications.
- Mount: a + toolbar button in the Applications shell and an action in the
  board's empty state, both opening the same sheet ([PIPEBOARD-20]).

## Consequences

- calendar-sync is hand-testable: add an applied Application for a company,
  press "Check calendar", and matching events surface.
- The empty state gains its first action and its copy widens beyond
  tailor-first.
- cv-export's criteria are untouched; a manual Application is
  export-shaped minus the CV fields, so every board behaviour (transitions,
  backfill, cards, timeline) applies to it unchanged.
- The [PIPEBOARD-8] backfill never touches manual rows: applied manual adds
  always carry a date, drafts are not backfilled by design.
