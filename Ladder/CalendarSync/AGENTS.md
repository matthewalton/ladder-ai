# Calendar Sync — working the slice

The slice owns the `CalendarSyncService` seam (protocol + fixture + live
EventKit implementation), the scan/match/propose store, the `DismissedEvent`
model, the confirmation sheet, and the calendar entitlement + usage string in
`project.yml`.

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
`project.yml` globs. Fixture events are constructed in code by the fixture
service — no calendar permission, no JSON files, no `EKEvent` in any test.
Store tests use an in-memory container
(`ProfileStore.container(inMemory: true)`); the [CALSYNC-12] persistence
criterion reopens a file-backed container via the shared
`temporaryStoreURL()`/`removeStore(at:)` helpers
(`Ladder/Profile/src/ProfilePersistenceTests.swift`).

Never construct a live `EKEventStore` in tests — the suite must stay green
with no calendar permission granted (ROADMAP Phase 2 exit criterion 4). The
live implementation is exercised by humans only.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[CALSYNC-n]`
  token in the test's display name (Swift Testing: `@Test("[CALSYNC-1] …")`).
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria.
