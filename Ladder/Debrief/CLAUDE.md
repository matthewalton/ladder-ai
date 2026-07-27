# Debrief

Generates a post-interview debrief from a Stage's notes overview via `IntelligenceService`:
the `Debrief` and `DebriefQuestion` models, the `GroundedRemark` value type, the
`DebriefStore`, the debrief section in the Stage's settings, and the rendering.

**Edits outside this folder** — a change here usually touches:

- `Ladder/PipelineBoard/src/Stage.swift` — the `Stage.debrief` link (pipeline-board owns the
  Stage model)
- `Ladder/Profile/src/ProfileStore.swift` — the `Debrief.self` / `DebriefQuestion.self`
  schema entries
- `Ladder/Shared/Services/` — the `debriefFixture()` loader on `FixtureIntelligenceService`
- `Prompts/debrief.md` — the prompt

**Traps**

- **The debrief is grounded in the notes.** Remarks are quote-validated against the interim;
  an ungrounded remark is a validation failure, not a stylistic problem (decisions/0002).
- `LadderTests/Fixtures/Phase3Store` was written by the Phase 3 schema — never regenerate it.
- Service tests inject `FixtureIntelligenceService` with
  `LadderTests/Fixtures/debrief-result.json`.
- Section layout, Generate enablement and failure copy can't be asserted headlessly —
  visual-verify.

Criteria token: `[DEBRIEF-n]`
