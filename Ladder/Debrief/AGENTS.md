# Debrief — working the slice

The slice owns the `Debrief` and `DebriefQuestion` models, the
`GroundedRemark` value type, the `DebriefStore` (guards, payload assembly,
validation, the one-repair loop, persistence), the debrief section in the
Stage's settings and the debrief rendering, `Prompts/debrief.md` and its
loader. Edits outside the folder: the `Stage.debrief` link in
`Ladder/PipelineBoard/src/Stage.swift` (pipeline-board owns the Stage
model), the `Debrief.self` / `DebriefQuestion.self` schema entries in
`Ladder/Profile/src/ProfileStore.swift`, the `debriefFixture()` loader on
`FixtureIntelligenceService` in `Ladder/Shared/Services/`, and
`Prompts/debrief.md` at the repo root (the canonical prompts location).

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
the `LadderTests` target by `project.yml` globs. Store-backed tests use an
in-memory container (`ProfileStore.container(inMemory: true)`); service
tests inject `FixtureIntelligenceService` with
`LadderTests/Fixtures/debrief-result.json` (the [TAILOR] flow-test
pattern). Dates are passed in explicitly (the [PIPEBOARD-16] pattern);
tests never read the clock. The `Phase3Store` fixture
(`LadderTests/Fixtures/Phase3Store`) was written by the Phase 3 schema —
never regenerate it.

Section layout, Generate enablement, and failure copy cannot be asserted
headlessly — they go on the session's visual-verify list. Colors and fonts
only via `Palette.swift` / `Typography.swift`.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[DEBRIEF-n]`
  token in the test's display name (Swift Testing:
  `@Test("[DEBRIEF-1] …")`).
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria: 0001 records the missed-ammo
  relationship and payload-index protocol, 0002 the notes-grounded interim
  and quote validation.
