# CV Import — working the slice

The slice owns CV import: on-device text extraction (PDF/docx), the
`IntelligenceService` protocol and `FixtureIntelligenceService` (in
`Ladder/Shared/Services/`), the proposal/review flow, the merge into the
Profile, and `Prompts/import.md`.

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

Code and tests are colocated in `src/` (Profile decisions/0001 set the pattern):
`*Tests.swift` files are routed to the `LadderTests` target by `project.yml`
globs. Fixture CVs and canned proposal JSON live in `LadderTests/Fixtures/`.
Production import is live: the run reads the API key via the shared
`APIKeyStore` and calls `AnthropicIntelligenceService` (both in
`Ladder/Shared/Services/`). Tests and previews never touch the network — they
inject `FixtureIntelligenceService` and fake key stores; the one Keychain test
pattern uses a throwaway UUID-namespaced service name.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[CVIMPORT-n]` token
  in the test's display name (Swift Testing: `@Test("[CVIMPORT-3] …")`).
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria.
