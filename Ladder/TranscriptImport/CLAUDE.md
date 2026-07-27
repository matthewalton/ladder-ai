# Transcript import

Imports an external (Granola) transcript onto a Stage: the `Transcript` model, the share-page
parsing, the attach/replace/remove notes flow on the Stage form, and the notes window.

**Edits outside this folder** — a change here usually touches:

- `Ladder/PipelineBoard/src/Stage.swift` — the `Stage.transcript` link (pipeline-board owns
  the Stage model)
- `Ladder/Profile/src/ProfileStore.swift` — the `Transcript.self` schema entry
- `Ladder/App/` — the notes `WindowGroup`

**Traps**

- The `Segment` value type is kept for the model's future consumers — **nothing here writes
  one**. It looking unused is expected, not dead code to delete.
- `LadderTests/Fixtures/Phase2Store` was written by the Phase 2 schema — never regenerate it.
- Payload parsing is pure (HTML in, `SharedDocument` out) and the fetch sits behind the
  `GranolaShareFetching` seam, so most criteria test without the network. Keep new work on
  that side of the seam.
- Window chrome, the attached indicator and failure copy can't be asserted headlessly —
  visual-verify.

Criteria token: `[TRANSCRIPT-n]`. Retired ids (see the SPEC intro) are never reused.
