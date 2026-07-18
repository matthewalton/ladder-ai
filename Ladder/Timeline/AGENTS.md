# Timeline — working the slice

The slice owns the per-Application timeline view and its derivation seam
(`TimelineModel` in `src/`), the pipeline shell's content toggle, and the
trail-blaze Shape set — the one piece living outside the folder, in
`Ladder/Shared/DesignSystem/` (decisions/0002), because board and Summit
View share it later. It writes nothing: every date it shows is persisted by
pipeline-board or calendar-sync.

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
the `LadderTests` target by `project.yml` globs. Derivations are
`TimelineModel` statics taking an explicit `asOf: Date` (the
[PIPEBOARD-16] pattern) so tests never depend on the clock. Store-backed
tests use an in-memory container
(`ProfileStore.container(inMemory: true)`).

Blaze geometry, the `pine` line, hollow/filled rendering, and toggle chrome
cannot be asserted headlessly — they go on the session's visual-verify
list. Colors and fonts only via `Palette.swift` / `Typography.swift`.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[TIMELINE-n]`
  token in the test's display name (Swift Testing: `@Test("[TIMELINE-2] …")`).
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria.
