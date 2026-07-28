# CV Export

Everything from tailor review onward: composing the PDF, the CV preview the user edits and
rules on, the export that commits it, save-panel delivery, and the fit report view.
Defines the `Application` SwiftData model in `src/`, as the slice that introduced it.

**Edits into this folder** — `src/Application.swift` is shared ground. Pipeline-board grew
it in place for Phase 2 (its decisions/0001) and journey-synthesis links to it; a slice
attaching something to an Application edits this file rather than copying the model.

**Edits outside this folder** — a change here usually touches:

- `Ladder/Features/Tailor/src/Views/TailorView.swift` — the flow's phase machine gains the
  preview phase between review and export. A code-level touch only; no TAILOR criterion
  changes, the precedent [CVEXPORT-4]'s body already set.
- `Ladder/Features/Tailor/src/TailorReview.swift` — `matchedTagNames` is readable so the
  preview can compute coverage against the confirmed Match ([CVEXPORT-38]). Same
  code-level-touch rule.
- `Ladder/Features/Profile/src/ProfileStore.swift` — Profile owns the tagging operation the
  preview's Tag write goes through ([CVEXPORT-54]); this slice never mints a `SkillTag`.
- `Prompts/rescore.md` — the re-score pass's versioned prompt ([CVEXPORT-55]). Prompts live
  there, never in the slice.

**Traps**

- Render tests assert content by **extracting text from the rendered PDF with PDFKit** —
  never by inspecting SwiftUI views.
- Flow tests drive a tailor run to review with `FixtureIntelligenceService`, then export. No
  test touches the real save panel.
- The print template is exempt from the `Palette` / `Typography` rule (decisions/0007) — it
  is the one place raw values are correct.
- Preview code goes in `src/Preview/`, not beside the render files — `src/` already holds
  six files flat and the convention caps a flat folder at ten.

Criteria token: `[CVEXPORT-n]`
