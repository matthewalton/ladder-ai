# ROADMAP.md — phases & slices

Phases are hard gates (ARCHITECTURE.md §4): **1 Profile + Tailor → 2 Pipeline → 3 Capture → 4 Intelligence → 5 Journey.** Nothing from a later phase starts before the prior phase's exit criteria pass; only the human advances the phase line in CLAUDE.md.

Acceptance criteria for behaviour live in each slice's SPEC.md (Speccle owns the contract). This file only maps the territory.

## Phase 0 — Scaffold *(plain setup, not a slice)*
- `project.yml` for XcodeGen: macOS app target `Ladder` (macOS 26), test target `LadderTests`, folder-based sources per CLAUDE.md layout
- Empty app boots to a `NavigationSplitView` shell; `.gitignore`
- `Palette.swift` + color assets (light/dark) exactly per DESIGN.md §2; `Typography.swift` helpers per §3
- Done when: `xcodegen generate && xcodebuild build && xcodebuild test` succeed headlessly; shell renders in both appearances.

## Phase 1 slices *(build in order with `/feature`)*
1. **profile** — `Profile`/`Role`/`Achievement` models (+ `SkillTag`, `ContactInfo`), single-profile invariant, CRUD editor (sidebar/content/inspector), drag-reorder, skill chips, empty state. Tracer: add a role, relaunch, it's still there.
2. **cv-import** — PDF/docx drop → text extraction → `IntelligenceService`-proposed profile → mandatory per-item review → confirmed merge into the Profile. Fixture-driven; `Prompts/import.md` is born here.
3. **tailor** — New Application sheet (company, role, JD paste) → achievement selection + per-achievement rephrasing + gap flags + rationale → side-by-side review. `Prompts/tailor.md`; schema validation with one retry-with-repair. Keychain API key entry in Settings turns live calls on here.
4. **cv-export** — `ImageRenderer` PDF (A4, single-column, ATS-parseable) → Application persisted with immutable `cvSnapshot` + `cvSelectionRationale`, status `.applied`; fit report view (strength/gap chips + New York prose).

## Phase 1 exit criteria
1. Fresh path: import real CV → curated profile → paste real JD → tailored PDF in under 5 minutes.
2. No raw hex/fonts in views; all tests green headlessly; previews compile.
3. `Prompts/` contains `import.md` and `tailor.md`, versioned.

## Phase 2 slices *(build in order with `/feature`)*
1. **pipeline-board** — `Stage` model + `Application` migration (`stages`, `appliedAt`, `source`, `notes`, status transitions) → applications board grouped by status with drag between columns → Stage CRUD on the application detail → app shell grows Profile/Applications navigation. Tracer: add a Stage to an exported Application, relaunch, it's still there.
2. **calendar-sync** — read-only EventKit scan (manual + background refresh) → meeting-URL detection (Zoom/Meet/Teams) → match to Applications by company name / attendee domain → confirmation sheet creates or links a Stage, never silently. `CalendarSyncService` protocol + fixture mirror the `IntelligenceService` seam; calendar entitlement + usage string are born here.
3. **timeline** — per-Application timeline: applied → heard back → each Stage → outcome, with elapsed-time annotations. Functional vocabulary only; the Summit View keepsake stays Phase 5.

## Phase 2 exit criteria
1. Fresh path: a calendar invite from a tracked company surfaces as a proposed Stage with zero typing; one confirmation later it appears on the board and the Application's timeline.
2. Migration safety: relaunching over a Phase 1 store keeps every Application, each `cvSnapshot` byte-identical.
3. Calendar posture: read-only access behind a protocol; the app stays fully usable when access is denied.
4. No raw hex/fonts in views; all tests green headlessly with no calendar permission granted; previews compile.

## Phase 3 slices *(build in order with `/feature`)*

Native capture is deferred (ADR 0002): interim transcripts come from Granola and enter the app by hand. The recorder slice was built (fe22ae5) then removed from the tree; it restores from git history when native capture returns.

1. **transcript-import** — `Transcript` + `Segment` models (ARCHITECTURE.md §3) colocated in the slice → `Stage.transcript` link → **rescoped 2026-07-20 to notes-only** (slice decisions/0007): a `notes.granola.ai` share link pasted in the Stage's settings fetches the call's notes overview and attaches it in one step; the Stage shows an attached indicator, full notes open in their own window. Transcript parsing/attribution retired — Granola share pages expose notes only (slice decisions/0006), so transcripts return with native capture. `segments` stays on the model, empty, for Phase 4.

### Deferred slices — native capture (ADR 0002; restore when the rest of the app has settled)
- **recorder** — `CaptureService` protocol + fixture → `MenuBarExtra` record control, level meters, consent, mic detect-and-guide. Built at fe22ae5; restore from history rather than rebuild.
- **transcription** — `Transcriber` protocol + fixture over on-device `SpeechAnalyzer`/`SpeechTranscriber` (ADR 0001), Stage picked at record time. Was specced; contract shelved with the recorder removal.
- **system-audio** — second stream via ScreenCaptureKit audio / Core Audio process taps → screen-recording onboarding → timestamp merge with mic = `.me` / system = `.them` attribution → `sourceApp` detection.
- **pre-call** — EventKit pre-call notification driven off `Stage.calendarEventID` → opens the recorder armed on the right Stage → notification detect-and-guide.

The deferred slices carry the native-capture privacy criteria with them (raw audio never persisted beyond the session; transcription fully on-device, no network egress; visible recording indicator; first-run consent; mic/screen-recording/notification denial never crashes).

## Phase 3 exit criteria
1. Fresh path: Granola share link of a real interview → its notes overview attached to the right Stage, surviving relaunch. *(Rescoped from attributed transcripts, 2026-07-20 — slice decisions/0007; the attributed-transcript path returns with native capture.)*
2. Migration safety: relaunching over a Phase 2 store keeps every Application, Stage, and `cvSnapshot` byte-identical.
3. No raw hex/fonts in views; all tests green headlessly; previews compile.

## Later phases
See ARCHITECTURE.md §4 for Phase 4–5 module definitions. Slice maps for those phases get drawn when the phase opens.
