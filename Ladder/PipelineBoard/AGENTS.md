# Pipeline Board — working the slice

The slice owns the `Stage` model (defined here in `src/`), the Phase 2 growth
of the `Application` model (migrated in place in `Ladder/CVExport/src/
Application.swift` — decisions/0001), the transition map, the board and
application detail views, the job-description edit and JD import on the
detail (decisions/0005 — the shared file→text extractor lives in
`Ladder/Shared/Services/`, not here), and the app shell's
Profile/Applications sections.

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

Code and tests are colocated in `src/` (Profile decisions/0001 set the
pattern): `*Tests.swift` files are routed to the `LadderTests` target by
`project.yml` globs. Store behaviour tests use an in-memory container
(`ProfileStore.container(inMemory: true)`); persistence criteria reopen a
file-backed container at the same URL using the shared
`temporaryStoreURL()`/`removeStore(at:)` helpers
(`Ladder/Profile/src/ProfilePersistenceTests.swift`).

The migration criterion [PIPEBOARD-2] opens a copy of the committed Phase 1
fixture store at `LadderTests/Fixtures/Phase1Store/` (copy the `.store` file
and its `-wal`/`-shm` sidecars together). Never regenerate that fixture from
current code — its whole value is that it was written by the Phase 1 schema.

No test drives drag-and-drop or the tab shell; all move legality lives in
`PipelineStore`, so the UI seam stays thin and the untestable parts go on the
session's visual-verify list.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[PIPEBOARD-n]`
  token in the test's display name (Swift Testing: `@Test("[PIPEBOARD-5] …")`).
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria.
