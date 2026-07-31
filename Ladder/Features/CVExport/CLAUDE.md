# CV Export

Everything from tailor review onward: composing the PDF, the CV preview the user edits and
rules on, the export that commits it, save-panel delivery, and the fit report view.
Defines the `Application` SwiftData model in `src/`, as the slice that introduced it.

**Edits into this folder** — `src/Application.swift` is shared ground. Pipeline-board grew
it in place for Phase 2 (its decisions/0001) and journey-synthesis links to it; a slice
attaching something to an Application edits this file rather than copying the model.

**Edits outside this folder** — a change here usually touches:

- `Ladder/Features/Tailor/src/Views/TailorView.swift` — the flow's phase machine gains the
  preview phase between review and export, and the sheet's floor is sized for that phase
  rather than the others (decisions/0015). A code-level touch only; no TAILOR criterion
  changes, the precedent [CVEXPORT-4]'s body already set.
- `Ladder/Features/Tailor/CLAUDE.md` — sizing the sheet here changes how tailor's own review
  screens are laid out, so what to check on them is briefed under that slice's **Needs eyes**.
- `Ladder/Features/Tailor/src/TailorReview.swift` — `matchedTagNames` is readable so the
  preview can compute coverage against the confirmed Match ([CVEXPORT-38]). Same
  code-level-touch rule.
- `Ladder/Features/Profile/src/ProfileStore.swift` — Profile owns the tagging operation the
  preview's Tag write goes through ([CVEXPORT-54]); this slice never mints a `SkillTag`.
- `Prompts/rescore.md` — the re-score pass's versioned prompt ([CVEXPORT-55]). Prompts live
  there, never in the slice.

**Needs eyes**

- The CV preview, three frames deep — `scripts/snapshots.sh app tailor` walks it to the role
  sections and the discard alert. What the frames answer: the page pane's legibility at the
  sheet's width, the ATS warning under each role's keep-toggle ([CVEXPORT-46]), and whether
  Coverage still reads as a different number from the Match score (decisions/0011). Legibility
  is measured, not judged: the `.txt` recorded beside each frame carries the pane and page
  widths, and the page is meant to clear A4 (decisions/0015).
- The over-length state — the tour seed makes a one-page CV, so nothing renders the clay page
  label, the "about N pages over" copy, or the disabled Export. Stays the human's.
- The "Not scored yet" line — only appears on a point added after the tailor run, which the
  tour never adds. Stays the human's.
- `PDFView` scroll and zoom behaviour, and the sheet's phase transitions — no snapshot shows
  motion or live scrolling.

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
