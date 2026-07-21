# Journey synthesis — working the slice

The slice owns the `JourneyNarrative` model, the `JourneyStore` (guards,
payload assembly, validation, the one-repair loop, persistence), the
journey section on the Application detail, and `Prompts/journey.md` and
its loader. Edits outside the folder: the `Application.journeyNarrative`
link in `Ladder/CVExport/src/Application.swift` (cv-export owns the
Application model), the `JourneyNarrative.self` schema entry in
`Ladder/Profile/src/ProfileStore.swift`, the `journeyFixture()` loader on
`FixtureIntelligenceService` in `Ladder/Shared/Services/`, the journey
section's mount point in
`Ladder/PipelineBoard/src/ApplicationDetailView.swift` (pipeline-board
owns the detail form), and `Prompts/journey.md` at the repo root (the
canonical prompts location).

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
`LadderTests/Fixtures/journey-result.json` (the [TAILOR] flow-test
pattern). Dates are passed in explicitly (the [PIPEBOARD-16] pattern);
tests never read the clock. The `Phase4PrepStore` fixture
(`LadderTests/Fixtures/Phase4PrepStore`) was written by the prep-era
Phase 4 schema — never regenerate it.

Section layout, generate-button enablement, failure copy, and the
confirmation dialog cannot be asserted headlessly — they go on the
session's visual-verify list. Colors and fonts only via `Palette.swift` /
`Typography.swift`.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[JOURNEY-n]`
  token in the test's display name (Swift Testing:
  `@Test("[JOURNEY-1] …")`).
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria: 0001 records the
  narrative-on-Application data shape, 0002 the plain-narrative service
  contract.
