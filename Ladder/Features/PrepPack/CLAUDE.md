# Prep pack

Generates interview prep for a Stage: the `PrepPack` and `PrepTalkingPoint` models, the
`MockTask` value type, the `PrepPackStore`, the prep-pack section in the Stage's settings,
and the markdown export.

**Edits outside this folder** — a change here usually touches:

- `Ladder/Features/PipelineBoard/src/Stage.swift` — the `Stage.prepPack` link (pipeline-board owns the
  Stage model)
- `Ladder/Features/Profile/src/ProfileStore.swift` — the `PrepPack.self` / `PrepTalkingPoint.self`
  schema entries
- `Ladder/Shared/Services/` — the `prepFixture()` loader on `FixtureIntelligenceService`
- `Prompts/prep.md` — the prompt

**Traps**

- **Prep coaching is ungrounded by design** (decisions/0002) — unlike debrief, it is not
  quote-validated against source notes. Do not copy debrief's validation here.
- `LadderTests/Fixtures/Phase4Store` was written by the debrief-era Phase 4 schema — never
  regenerate it.
- Service tests inject `FixtureIntelligenceService` with `LadderTests/Fixtures/prep-result.json`.
- Section layout, Generate enablement, failure copy and the export save panel can't be
  asserted headlessly — visual-verify.

Criteria token: `[PREP-n]`
