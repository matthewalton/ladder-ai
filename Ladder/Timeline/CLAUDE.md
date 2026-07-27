# Timeline

The per-Application timeline view and its derivation seam (`TimelineModel`), plus the
pipeline shell's content toggle.

**Edits outside this folder** — a change here usually touches:

- `Ladder/Shared/DesignSystem/` — the trail-blaze `Shape` set lives there, not here
  (decisions/0002), because the board and Summit View share it later

**Traps**

- **This slice writes nothing.** Every date it shows is persisted by pipeline-board or
  calendar-sync. A change that needs new stored data belongs in one of those slices.
- Derivations are `TimelineModel` statics taking an explicit `asOf: Date`.
- Blaze geometry, the `pine` line, hollow/filled rendering and toggle chrome can't be
  asserted headlessly — visual-verify.

Criteria token: `[TIMELINE-n]`
