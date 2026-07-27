# CV Export

Everything from tailor review onward: the PDF render, save-panel delivery, and the fit
report view. Defines the `Application` SwiftData model in `src/`, as the slice that
introduced it.

**Edits into this folder** — `src/Application.swift` is shared ground. Pipeline-board grew
it in place for Phase 2 (its decisions/0001) and journey-synthesis links to it; a slice
attaching something to an Application edits this file rather than copying the model.

**Traps**

- Render tests assert content by **extracting text from the rendered PDF with PDFKit** —
  never by inspecting SwiftUI views.
- Flow tests drive a tailor run to review with `FixtureIntelligenceService`, then export. No
  test touches the real save panel.
- The print template is exempt from the `Palette` / `Typography` rule (decisions/0007) — it
  is the one place raw values are correct.

Criteria token: `[CVEXPORT-n]`
