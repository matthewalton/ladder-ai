# Journey synthesis

Synthesises an Application's journey into a narrative: the `JourneyNarrative` model, the
`JourneyStore`, the journey section on the Application detail, and its prompt.

**Edits outside this folder** — a change here usually touches:

- `Ladder/CVExport/src/Application.swift` — the `Application.journeyNarrative` link
  (cv-export owns the Application model)
- `Ladder/Profile/src/ProfileStore.swift` — the `JourneyNarrative.self` schema entry
- `Ladder/Shared/Services/` — the `journeyFixture()` loader on `FixtureIntelligenceService`
- `Ladder/PipelineBoard/src/Views/ApplicationDetailView.swift` — the section's mount point
  (pipeline-board owns the detail form)
- `Prompts/journey.md` — the prompt

**Traps**

- This slice hangs off **Application**, not Stage — the opposite of debrief and prep pack.
  Its narrative spans the whole application, so a Stage-scoped assumption is wrong here.
- The service contract is a plain narrative (decisions/0002), not a structured payload.
- `LadderTests/Fixtures/Phase4PrepStore` was written by the prep-era Phase 4 schema — never
  regenerate it.
- Service tests inject `FixtureIntelligenceService` with
  `LadderTests/Fixtures/journey-result.json`.
- Section layout, generate-button enablement, failure copy and the confirmation dialog can't
  be asserted headlessly — visual-verify.

Criteria token: `[JOURNEY-n]`
