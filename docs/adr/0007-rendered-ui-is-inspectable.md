# 0007 — Rendered UI is inspectable, by two complementary routes

**Status:** accepted (2026-07-29)

## Context

Nothing in the repo could look at rendered SwiftUI. `CLAUDE.md` said so
outright, and every UI task therefore ended in a hand-written list of things
for the human to check by eye. That put the human in the loop for questions a
machine can answer — is the spacing right, did dark mode break, is the empty
state's copy still centred — and it made UI work the slowest kind of work in
the project.

Two mechanisms can answer those questions. Neither answers all of them.

`ImageRenderer` draws a `View` to a `CGImage` in-process, with no window, no
permissions and no display session. It is fast enough to run in the test
bundle. But it only draws what SwiftUI itself draws: `TextField`, `List` and
`Form` rows, and scrolling containers come out blank, and `TabView` renders as
the system's unavailable glyph — so the app shell and every screen built on a
list is invisible to it.

`XCUITest` launches the real app and photographs it, so what comes back is
exactly what the human sees, chrome and controls included. It costs a window,
about twenty seconds, and — because it drives the shipping app — it would open
the human's own store and calendar unless told otherwise.

## Decision

Both, each owning what it is good at.

- **Components** — `LadderTests/SnapshotGallery.swift` renders leaf views to
  `.snapshots/`, light and dark. It is a normal test in `LadderTests`, gated
  on `LADDER_SNAPSHOTS=1` so the everyday suite is unchanged.
- **Screens** — `LadderUITests/ScreenTour.swift` drives the real app and
  attaches a screenshot *and an accessibility-hierarchy dump* per step. It
  lives in its own `LadderUI` scheme, so `-scheme Ladder test` stays the fast
  headless suite.
- `scripts/snapshots.sh` runs either or both and lifts the tour's attachments
  out of the result bundle into `.snapshots/ui/` under the names the tour gave
  them.
- `.snapshots/` is generated and git-ignored.

The tour passes `-LadderScratchStore`. `LadderApp` reads it and opens a
throwaway store under the temporary directory and a `FixtureCalendarSyncService`
instead of EventKit. This is the only launch-argument branch in the app.

## Consequences

- UI changes can be verified before the human sees them. The visual-verify list
  survives, but only for what neither route captures: motion, drag-and-drop,
  materials and vibrancy, and anything that needs a live pointer.
- `#Preview` stays mandatory. Previews remain the fastest loop for a human in
  Xcode, and the gallery does not replace them.
- The tour is a real UI test and can fail — a renamed control breaks it. That
  is a feature: it is the only automated check that the app launches and its
  primary flow is reachable.
- Adding a screen to the tour means reading its hierarchy dump first; that is
  why every step attaches one.
- A launch argument that swaps the store is a hazard of exactly the kind ADR
  0004 was written about. It is deliberately one flag, named for what it does,
  and it only ever *narrows* to a scratch path — no argument can point the app
  at a different real store.
