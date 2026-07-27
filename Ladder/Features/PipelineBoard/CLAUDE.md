# Pipeline Board

The `Stage` model, the transition map, the applications board and the application detail
view, the job-description edit and JD import on that detail, and the app shell's
Profile/Applications sections.

**Edits into this folder** — two files here are shared ground:

- `src/Stage.swift` — every slice that attaches to a Stage (transcript, debrief, prep pack)
  adds its link here
- `src/Views/ApplicationDetailView.swift` — the detail form; a slice adding a section mounts
  it here

**Edits outside this folder** — a change here usually touches:

- `Ladder/Features/CVExport/src/Application.swift` — cv-export owns `Application`; the Phase 2 growth
  was migrated in place there (decisions/0001)
- `Ladder/Shared/Services/` — the shared file→text extractor the JD import uses
  (decisions/0005), not a copy in this slice
- `Ladder/Features/Tailor/src/` — the Match section on the detail is an on-demand JD scan **door**
  (decisions/0009); the scan machinery and the Match review it presents live in tailor

**Traps**

- The migration criterion `[PIPEBOARD-2]` opens a copy of `LadderTests/Fixtures/Phase1Store/`.
- No test drives drag-and-drop or the tab shell. All move legality lives in `PipelineStore`
  so the UI seam stays thin — keep it that way; the untestable parts go on the visual-verify
  list.

Criteria token: `[PIPEBOARD-n]`
