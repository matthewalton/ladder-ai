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

**Planning a UI slice settles what needs eyes.** When the work will draw anything, the plan says which screens and components must be looked at, and captures that under a `**Needs eyes**` heading in the slice's `CLAUDE.md` — one line per screen, naming what to check. That heading is the visual lens's brief at review time; `/review` fires the lens on any change set touching a view, and reads the heading to know how deep to go (`.speccle/lenses/visual.md`, ADR 0007). Plans that touch no view say so and skip it. The `visual-coverage` plan lens (`.speccle/lenses/plan/`) holds a UI plan to this in every `/feature` planning session.

**Drawing means looking, and a new surface means new coverage (ADR 0008).** An implement session whose criterion touched anything that draws renders the affected sections (`scripts/snapshots.sh`) and reads the PNGs before committing — the checks-gate cannot express this, so it holds by instruction, and skipping it is committing a screen nobody saw. A slice that introduces a new screen or component is not done until the machinery can see it: a new tour section (`testTour<Name>Section` in `ScreenTour.swift` plus its `tour_test` case in `scripts/snapshots.sh`) for a screen, a `SnapshotGallery` entry for a component. That coverage lands with the criterion that introduces the surface; the visual lens majors on a new surface it cannot render.

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

# Render the UI to .snapshots/ so it can be looked at (ADR 0007)
scripts/snapshots.sh views   # components, headless, ~20s
scripts/snapshots.sh app     # the real app, driven and photographed, ~40s
scripts/snapshots.sh app stage-sheet tailor   # only those tour sections (list in the script)
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
LadderTests/      unit suite + SnapshotGallery.swift (component renders, ADR 0007)
LadderUITests/    ScreenTour.swift — drives the real app and photographs it (ADR 0007)
scripts/
docs/adr/
```

## Conventions

- MVVM-lite: SwiftUI views + `@Observable` stores. No third-party architecture frameworks.
- All LLM access behind `IntelligenceService`. Development uses `FixtureIntelligenceService` returning canned JSON from `LadderTests/Fixtures/` — no live API calls until the tailor slice turns them on.
- API key: Keychain only. Never UserDefaults, never in code, never logged.
- Colors/fonts: only via `Palette.swift` / `Typography.swift` accessors. No raw hex or `.custom` fonts in views (Summit View exempt later, per DESIGN.md §3; the rendered CV's print template exempt per CVExport decisions/0007).
- Dependencies: none without asking.
- Comments: almost none. Names carry the meaning — never restate a declaration or body, never narrate steps, never write doc-comment summaries that repeat the signature, and never cite criteria/decisions for behaviour the code makes plain (traceability lives in SPEC.md, decisions/, and git history, not in source). A comment earns its place only by stating something the code cannot: a framework quirk, a hard-won trap, deliberately surprising test data. `// MARK:` markers are fine. `@Test("[TOKEN-n] …")` names are string literals, not comments — never strip them.
- Rendered UI can be seen, two ways (ADR 0007) — `scripts/snapshots.sh views` renders components headlessly into `.snapshots/`, light and dark; `scripts/snapshots.sh app` drives the real app and photographs each screen into `.snapshots/ui/`. Look at the PNGs before claiming a UI change works. Neither route covers motion, drag-and-drop, materials or vibrancy: keep `#Preview` on every view and still end a UI session with the list of what the human must check by eye. Each slice's `CLAUDE.md` names the parts of that slice needing eyes.

## Testing

These hold for every slice; a slice's own `CLAUDE.md` records only what differs.

- Code and tests are colocated in each slice's `src/`. `*Tests.swift` files are routed to the `LadderTests` target by `project.yml` globs (Profile decisions/0001) — they compile into the test bundle, not the app.
- Every SwiftData model change needs a round-trip persistence test. Store tests use an in-memory container (`ProfileStore.container(inMemory: true)`); persistence criteria reopen a file-backed container at the same URL via the shared `temporaryStoreURL()` / `removeStore(at:)` helpers in `Ladder/Features/Profile/src/ProfilePersistenceTests.swift`.
- Dates are passed in explicitly (the `[PIPEBOARD-16]` pattern). Tests never read the clock.
- Committed fixture stores under `LadderTests/Fixtures/` were each written by an older schema — **never regenerate one**. That is their entire value. Copy the `.store` file with its `-wal`/`-shm` sidecars together.
- No test touches the network: inject `FixtureIntelligenceService` and fake key stores.
