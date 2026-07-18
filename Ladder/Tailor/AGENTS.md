# Tailor — working the slice

The slice owns the tailor flow: the tailor sheet, the run through
`IntelligenceService`, result validation with the repair loop, the
side-by-side review, `Prompts/tailor.md`, the Settings scene with Keychain
API key entry, and the live `AnthropicIntelligenceService` (in
`Ladder/Shared/Services/`).

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
`project.yml` globs. Canned tailor-result JSON lives in
`LadderTests/Fixtures/`. Tests never touch the network: the live service is
tested at its request-building seam, the flow with
`FixtureIntelligenceService`, and the Keychain store is faked behind its
protocol everywhere except its own round-trip test.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[TAILOR-n]` token
  in the test's display name (Swift Testing: `@Test("[TAILOR-4] …")`).
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria.
