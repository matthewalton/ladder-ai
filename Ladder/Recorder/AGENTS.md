# Recorder — working the slice

The slice owns the `CaptureService` seam (protocol + fixture + live
AVAudioEngine implementation), the `RecorderStore`, the `MenuBarExtra` scene
and its popover views, the consent screen, and the microphone entitlement +
usage string in `project.yml` / `Ladder/App/Ladder.entitlements`.

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

Code and tests are colocated in `src/`: `*Tests.swift` files are routed to
the `LadderTests` target by `project.yml` globs. Fixture buffers are
constructed in code by `FixtureCaptureService` — no microphone permission,
no audio files, no `AVAudioEngine` in any test.

Never construct a live `AVAudioEngine` or query `AVCaptureDevice` in tests —
the suite must stay green with no permissions granted (ROADMAP Phase 3 exit
criterion 5). The live implementation is exercised by humans only.

Consent tests inject a scratch `UserDefaults` suite (decisions/0002); never
touch the standard suite from a test.

## The contract

- `SPEC.md` — the criteria; tests claim one by putting its `[RECORDER-n]`
  token in the test's display name (Swift Testing: `@Test("[RECORDER-1] …")`).
- `CONTEXT.md` — the slice's language; use these terms in code and tests.
- `decisions/` — choices spanning criteria.
