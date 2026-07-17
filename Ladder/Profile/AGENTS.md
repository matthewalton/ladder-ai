# Profile — working the slice

The slice owns the single canonical Profile: the SwiftData models (`Profile`,
`Role`, `Achievement`, `SkillTag`, `ContactInfo`), the store enforcing the
single-profile invariant, and the sidebar/content/inspector editor.

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

Code and tests are colocated in `src/` (decisions/0001): test files are named
`*Tests.swift` and are routed to the `LadderTests` target by `project.yml`
include/exclude globs — they compile into the test bundle, not the app.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[PROFILE-n]` token in
  the test's display name (Swift Testing: `@Test("[PROFILE-4] …")`).
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria.

Stores are tested with an in-memory `ModelContainer`; persistence criteria reopen
a file-backed container at the same URL. Fixture data lives in the tests — no
network, no live LLM calls in this slice.
