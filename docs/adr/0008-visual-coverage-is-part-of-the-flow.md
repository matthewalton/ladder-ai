# 0008 — Visual coverage is part of the flow

**Status:** accepted (2026-07-31)

## Context

ADR 0007 made the rendered UI inspectable — components through the gallery,
screens through the tour — but running either stayed voluntary. The review
panel's visual lens looks at any change set touching a view, so `/review` was
covered; the `/feature` inner loop was not: an implement session could commit a
view change on a green checks-gate without a PNG ever being rendered. And
nothing anywhere required a *new* screen to enter the tour at all — the lens
would note "unrendered screen" and move on, so a slice could ship a surface no
automated eye would ever see.

A deterministic check cannot close this. `.speccle/checks/` predicates match
changed files by glob and regex, with no way to tell a new view from an edit to
one an existing tour section already photographs — any check would breach on
every view tweak and demand tour edits the existing sections already cover.

## Decision

Two rules, held at three points in the flow:

1. **A change to something that draws gets looked at** — rendered and read as
   PNGs, not reasoned about from the diff.
2. **A surface the change introduces gets its own coverage** — a new screen
   costs a tour section, a new leaf component costs a gallery entry, paid
   inside the slice that adds the surface.

The hooks, one per stage:

- **Plan** — `.speccle/lenses/plan/visual-coverage.md` runs in every `/feature`
  plan session: a plan that draws must carry a `**Needs eyes**` heading, and a
  plan that introduces a screen or component must name the tour section or
  gallery entry that will photograph it.
- **Implement** — a criterion that touched anything that draws renders the
  affected sections and reads the PNGs before committing (CLAUDE.md, Workflow).
  Instruction, not gate: `verify` cannot express it.
- **Review** — the visual lens escalates: a surface the change set introduces
  that neither the tour nor the gallery renders is a **major** finding, and its
  fix is the coverage itself.

## Consequences

- A new screen costs a `testTour<Name>Section` in `ScreenTour.swift` plus its
  case in `scripts/snapshots.sh` (`tour_test` and both section lists); a new
  leaf component costs a `SnapshotGallery` entry — unless `ImageRenderer`
  cannot draw it (ADR 0007), in which case the tour carries it instead.
- Editing a screen the tour already walks costs only the look: render the
  section, read the PNGs.
- Implement sessions on UI criteria get slower by one section render (~40s).
  That is the price of never committing a screen nobody saw.
- The human-eyes list survives unchanged: motion, drag-and-drop, materials and
  vibrancy still end every UI session as a list for the human (ADR 0007).
