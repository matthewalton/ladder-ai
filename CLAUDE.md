# CLAUDE.md — Ladder

macOS-native interview companion. SwiftUI + SwiftData, **macOS 26 only** (ADR 0001). Product name is "Ladder"; the repo is `ladder-ai`.

## Source-of-truth documents (read before any task)

- `ARCHITECTURE.md` — product thesis, data model, modules, build phases, privacy rules
- `DESIGN.md` — palette, typography, components, motion, Summit View spec
- `CONTEXT.md` — domain glossary; use these terms in code, UI, and docs (canonical term is **Profile**, never "vault"/"CareerProfile")
- `docs/adr/` — recorded architecture decisions
- `ROADMAP.md` — phase gates and the current phase's slice map

If a task conflicts with these docs, stop and flag it — do not silently deviate.

## Workflow: Speccle

Features are built with the Speccle skills, not ad-hoc. Start at `/feature`, which routes the work (new slice vs amendment vs carve) and hands off to the rest. The installed skills describe themselves — don't mirror their roster here, it only goes stale; `.speccle/config.json` pins the version.

Each feature slice owns its markdown contract; acceptance criteria live in the slice's `SPEC.md`, not in a global task list. Cross-cutting decisions become ADRs in `docs/adr/`; slice-local decisions go in the slice's `decisions/`. There is no DECISIONS.md. Each slice's own `CLAUDE.md` carries what that slice needs beyond this file — chiefly the edits a change there forces outside its folder.

## Current phase: **4 — Intelligence**

Hard gate: do not create or modify anything under `Ladder/Features/Journey/`. Phase gates are defined in ARCHITECTURE.md §4 and only the human advances them (by editing this line).

## Project setup

The Xcode project is generated — never edit `Ladder.xcodeproj` directly.

```bash
# Regenerate project after adding/removing files
xcodegen generate

# Build (headless)
xcodebuild -project Ladder.xcodeproj -scheme Ladder -destination 'platform=macOS' build

# Tests (headless)
xcodebuild -project Ladder.xcodeproj -scheme Ladder -destination 'platform=macOS' test
```

`project.yml` is the manifest. New source files go in the right feature folder and are picked up automatically by the folder-based target definition — but always run `xcodegen generate` + a build after adding files.

## Repo layout

```
Ladder/
  App/            entry point, app-level state
  Shared/
    Models/       SwiftData models (ARCHITECTURE.md §3)
    DesignSystem/ Palette.swift, Typography.swift, Blaze shapes
    Services/     protocol definitions + implementations
  Features/       every Speccle slice, one folder each — nothing else lives here
    Profile/        Phase 1 slice: profile editor
    CVImport/       Phase 1 slice: CV import (PDF/docx → review → merge)
    Tailor/         Phase 1 slice: JD → tailored, reviewed outcome
    CVExport/       Phase 1 slice: CV render + export (owns the Application model)
    PipelineBoard/  Phase 2 slice: Stage model, applications board, transitions
    Timeline/       Phase 2 slice: the trail view over an application's stages
                    (Phase 2 slices are siblings like this — no umbrella Pipeline/)
    TranscriptImport/ Phase 3 slice: import external (Granola) transcripts onto a Stage
    CalendarSync/   Phase 3 slice: read-only calendar scan → stage proposals
                    (Phase 3 slices are siblings — no umbrella Capture/. Native capture
                     is deferred per ADR 0002: Recorder/ was built then removed at
                     fe22ae5; Transcription/, SystemAudio/, PreCall/ return with it)
    Debrief/        Phase 4 slice (current): Debrief model + generation from a
                    Stage's notes overview via IntelligenceService
    PrepPack/       Phase 4 slice (current): prep pack generation for a Stage
    JourneySynthesis/ Phase 4 slice (current): the application's journey narrative
                    (Phase 4 slices are siblings — no umbrella Intelligence/)
    Journey/        Phase 5 (gated)
Prompts/          versioned LLM prompt files (*.md) — canonical location (never TailorPrompts/)
LadderTests/
docs/adr/
```

## Conventions

- MVVM-lite: SwiftUI views + `@Observable` stores. No third-party architecture frameworks.
- All LLM access behind `IntelligenceService`. Development uses `FixtureIntelligenceService` returning canned JSON from `LadderTests/Fixtures/` — no live API calls until the tailor slice turns them on.
- API key: Keychain only. Never UserDefaults, never in code, never logged.
- Colors/fonts: only via `Palette.swift` / `Typography.swift` accessors. No raw hex or `.custom` fonts in views (Summit View exempt later, per DESIGN.md §3; the rendered CV's print template exempt per CVExport decisions/0007).
- Dependencies: none without asking.
- You cannot see rendered SwiftUI. For UI tasks: build cleanly, keep previews compiling (`#Preview` on every view), and list what the human should visually verify at the end of the session. Each slice's `CLAUDE.md` names the parts of that slice needing eyes.

## Testing

These hold for every slice; a slice's own `CLAUDE.md` records only what differs.

- Code and tests are colocated in each slice's `src/`. `*Tests.swift` files are routed to the `LadderTests` target by `project.yml` globs (Profile decisions/0001) — they compile into the test bundle, not the app.
- Every SwiftData model change needs a round-trip persistence test. Store tests use an in-memory container (`ProfileStore.container(inMemory: true)`); persistence criteria reopen a file-backed container at the same URL via the shared `temporaryStoreURL()` / `removeStore(at:)` helpers in `Ladder/Features/Profile/src/ProfilePersistenceTests.swift`.
- Dates are passed in explicitly (the `[PIPEBOARD-16]` pattern). Tests never read the clock.
- Committed fixture stores under `LadderTests/Fixtures/` were each written by an older schema — **never regenerate one**. That is their entire value. Copy the `.store` file with its `-wal`/`-shm` sidecars together.
- No test touches the network: inject `FixtureIntelligenceService` and fake key stores.
