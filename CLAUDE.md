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
Features are built with the Speccle skills, not ad-hoc:
- `/plan-feature` to route work (new slice vs amendment vs carve)
- `/feature` to build a slice end-to-end (spec → tagged tests → implementation → oracle gate)
- `/implement-feature` when a linted SPEC.md already exists
- `/strengthen` to measure and improve oracle strength

Each feature slice owns its markdown contract (SPEC.md etc.); acceptance criteria live there, not in a global task list. Cross-cutting decisions become ADRs in `docs/adr/`; slice-local decisions go in the slice's `decisions/`. There is no DECISIONS.md.

## Current phase: **4 — Intelligence**
Hard gate: do not create or modify anything under `Journey/`. Phase gates are defined in ARCHITECTURE.md §4 and only the human advances them (by editing this line).

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
  Profile/        Phase 1 slice: profile editor
  CVImport/       Phase 1 slice: CV import (PDF/docx → review → merge)
  Tailor/         Phase 1 slice: JD → tailored, reviewed outcome
  CVExport/       Phase 1 slice: CV render + export (owns the Application model)
  PipelineBoard/  Phase 2 slice: Stage model, applications board, transitions
                  (Phase 2 slices are siblings like this — no umbrella Pipeline/)
  TranscriptImport/ Phase 3 slice: import external (Granola) transcripts onto a Stage
                  (Phase 3 slices are siblings — no umbrella Capture/. Native capture
                   is deferred per ADR 0002: Recorder/ was built then removed at
                   fe22ae5; Transcription/, SystemAudio/, PreCall/ return with it)
  Debrief/        Phase 4 slice (current): Debrief model + generation from a
                  Stage's notes overview via IntelligenceService
                  (Phase 4 slices are siblings — no umbrella Intelligence/;
                   PrepPack/ and JourneySynthesis/ follow per ROADMAP.md)
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
- Tests: every SwiftData model change needs a round-trip persistence test. Stores get unit tests with in-memory `ModelContainer`.
- You cannot see rendered SwiftUI. For UI tasks: build cleanly, keep previews compiling (`#Preview` on every view), and list what the human should visually verify at the end of the session.
