# CV Export — working the slice

The slice owns the export from tailor review onward: the `Application`
SwiftData model (defined here in `src/`, the slice that introduced it — the
same pattern as `ProfileModels.swift` in the Profile slice), the PDF render,
the save-panel delivery, and the fit report view.

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
`project.yml` globs. Render tests assert content by extracting text from the
rendered PDF with PDFKit — never by inspecting SwiftUI views. Flow tests
drive a tailor run to review with `FixtureIntelligenceService` (canned JSON
in `LadderTests/Fixtures/`), then export; no test touches the network or the
real save panel.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[CVEXPORT-n]`
  token in the test's display name (Swift Testing: `@Test("[CVEXPORT-4] …")`).
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria.
