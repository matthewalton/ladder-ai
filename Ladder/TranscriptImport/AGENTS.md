# Transcript import — working the slice

The slice owns the `Transcript` model, the `Segment` value type, the parser
that turns Granola-style labeled text into attributed segments, the
paste/drop/share-link → preview → confirm import flow (the link door's
fetch sits behind `GranolaShareFetching` with a fixture in tests), and the
readout on the Stage detail. It also adds the `Stage.transcript` link — the one edit outside the
folder, in `Ladder/PipelineBoard/src/Stage.swift`, because pipeline-board
owns the Stage model.

## Commands

```sh
# After adding or removing files (project is generated — never edit Ladder.xcodeproj)
xcodegen generate

# Build
xcodebuild -project Ladder.xcodeproj -scheme Ladder -destination 'platform=macOS' build

# Tests
xcodebuild -project Ladder.xcodeproj -scheme Ladder -destination 'platform=macOS' test
```

## Layout

Code and tests are colocated in `src/`; `*Tests.swift` files are routed to
the `LadderTests` target by `project.yml` globs. The parser and preview
derivation are pure — text in, segments/preview model out — so most
criteria test without a store; store-backed tests use an in-memory
container (`ProfileStore.container(inMemory: true)`). Dates are passed in
explicitly (the [PIPEBOARD-16] pattern); tests never read the clock.

Sheet chrome, me/them visual treatment, the replace warning copy, and the
drop-target highlight cannot be asserted headlessly — they go on the
session's visual-verify list. Colors and fonts only via `Palette.swift` /
`Typography.swift`.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[TRANSCRIPT-n]`
  token in the test's display name (Swift Testing:
  `@Test("[TRANSCRIPT-5] …")`).
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria, all agreed at plan
  (2026-07-20).
