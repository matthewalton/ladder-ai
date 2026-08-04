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
- `Ladder/Shared/DesignSystem/CollapsedContent.swift` — the shared `IndicatorRow` this slice's
  two detail views collapse into, also called by DEBRIEF, PREP and TRANSCRIPT. Anything added
  for a row here (docs/adr/0006 gave it a detail line and a configurable open-affordance label)
  defaults to today's behaviour, so those call sites stay untouched

**Needs eyes**

- The board with cards in every column — `scripts/snapshots.sh app`; the column layout and
  card rhythm are what break, and `ImageRenderer` renders the board blank.
- The Profile/Applications tab shell — only the tour shows it; `ImageRenderer` draws
  `TabView` as the unavailable glyph.
- Dragging a card between columns — no snapshot shows motion, so this one stays the
  human's, every time.
- The Match section's live-failure arm, on a service that refuses — never photographed, and
  the only one of the five surfaces showing live failure copy that sits inside a column
  rather than a sheet or a rail. What the frame answers is whether the Detail and the Advice
  (Tailor decisions/0022) still read as one block at a card's width, which is narrower than
  either failure sheet.

**Traps**

- The migration criterion `[PIPEBOARD-2]` opens a copy of `LadderTests/Fixtures/Phase1Store/`.
- No test drives drag-and-drop or the tab shell. All move legality lives in `PipelineStore`
  so the UI seam stays thin — keep it that way; the untestable parts go on the visual-verify
  list.

Criteria token: `[PIPEBOARD-n]`
