# Transcript import — working the slice

The slice owns the `Transcript` model, the `Segment` value type (kept for
the model's future consumers; nothing here writes one), the Granola share
page parsing (`GranolaSharePayload`, behind the `GranolaShareFetching`
seam), the attach/replace/remove notes flow on the Stage form, and the
notes window. Edits outside the folder: the `Stage.transcript` link in
`Ladder/PipelineBoard/src/Stage.swift` (pipeline-board owns the Stage
model), the `Transcript.self` schema entry in
`Ladder/Profile/src/ProfileStore.swift`, and the notes `WindowGroup` in
`Ladder/App/`.

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
the `LadderTests` target by `project.yml` globs. Payload parsing is pure
(HTML in, `SharedDocument` out) and the fetch is a protocol seam, so most
criteria test without the network; store-backed tests use an in-memory
container (`ProfileStore.container(inMemory: true)`). Dates are passed in
explicitly (the [PIPEBOARD-16] pattern); tests never read the clock. The
Phase2Store fixture (`LadderTests/Fixtures/Phase2Store`) was written by
the Phase 2 schema — never regenerate it.

Window chrome, the attached indicator, and failure copy cannot be asserted
headlessly — they go on the session's visual-verify list. Colors and fonts
only via `Palette.swift` / `Typography.swift`.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[TRANSCRIPT-n]`
  token in the test's display name (Swift Testing:
  `@Test("[TRANSCRIPT-28] …")`). Retired ids (see SPEC intro) are never
  reused.
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria; 0007 records the notes-only
  rescope.
