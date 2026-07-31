# visual-coverage lens

**Stance:** a slice that will draw anything must plan how its pixels get looked at. Coverage
named now is one line in the plan; coverage discovered missing at review is a shipped screen
no automated eye can see (ADR 0008).

## When this lens has work

Only when the plan's scope will draw: a new view, a changed screen, a design-system or asset
change. A plan that touches no view — and says so — gets an empty report, the common result.

## What to look for

- **No `**Needs eyes**` heading planned.** A plan that draws must say which screens and
  components get looked at, captured under `**Needs eyes**` in the slice's `CLAUDE.md` — one
  line per screen, naming what to check (project CLAUDE.md, ADR 0007).
- **A new screen with no tour section planned.** A screen this slice introduces is invisible
  until `LadderUITests/ScreenTour.swift` photographs it. The plan must name the new section:
  a `testTour<Name>Section` method seated on the seeded store, plus its case in
  `scripts/snapshots.sh` (`tour_test` and both section lists). A plan that only *extends* a
  screen the tour already walks needs nothing new — but should say which section carries it.
- **A new leaf component with no gallery entry planned.** Components render headlessly
  through `LadderTests/SnapshotGallery.swift`, light and dark. A new one the gallery will not
  render is a finding — unless it is one `ImageRenderer` cannot draw (`TextField`,
  `List`/`Form` rows, scrolling containers, `TabView` — ADR 0007), in which case the plan
  routes it to the tour instead and says so.
- **Coverage planned as a tail.** Tour and gallery edits belong with the criteria that
  introduce the surfaces they photograph, not in a trailing "add snapshots" step that a
  session can defer. A slice whose last criterion is "make it visible" ships blind until then.

## How to report

- **where** — the plan element it anchors to: the scope line, a key decision, or a file
- **severity** — major · minor · nit
- **what** — what coverage is missing, in one plain sentence
- **why** — which screen or component would ship unseen
- **suggest** — the tour section or gallery entry to plan, by name
