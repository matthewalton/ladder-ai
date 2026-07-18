# 0002 — The trail-blaze Shape set lives in Shared/DesignSystem

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

DESIGN.md §5 defines one custom icon set — the trail blazes — appearing on
the board, the timeline, and the Phase 5 Summit View: "a single icon
language from tracking through to celebration". No blaze exists in code yet;
this slice's nodes are the first consumer ([TIMELINE-10], [TIMELINE-11]).
CLAUDE.md's repo layout already names "Blaze shapes" as DesignSystem
content. The choice was to build the set now in its shared home, or ship
placeholder circles and defer.

## Decision

Build the five-shape set now — circle, diamond, square, double-chevron,
flag — as SwiftUI `Shape`s in `Ladder/Shared/DesignSystem/`, each drawable
filled or hollow, tinted only via `Palette` accessors. The kind → blaze
mapping (a total function over `StageKind`, families grouped per
[TIMELINE-11]'s body) ships in this slice beside the timeline that uses it.

## Consequences

- The one deliberate reach outside the feature folder: the shapes sit with
  Palette and Typography so the board's waypoint chip and the Summit View
  can adopt them without moving code. Everything else stays in `src/`.
- The timeline's look is final from day one — no placeholder-then-blaze
  churn.
- Shape geometry is untestable headlessly; it rides the visual-verify list,
  while the kind → blaze mapping is asserted in tests.
