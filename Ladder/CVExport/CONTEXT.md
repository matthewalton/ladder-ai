# CV Export — language

Slice-local terms. `Profile`, `Role`, `Achievement`, `Application`, and
`Tailoring` are defined in the root `CONTEXT.md`; `reviewed outcome`, `gap`,
and `rationale` in `Ladder/Tailor/CONTEXT.md`. None is restated here.

**Export**:
The slice's one action: render the CV, persist the Application (snapshot,
rationale, status applied), and offer the save panel. One render feeds both
destinations.
_Avoid_: submit, apply, send, generate

**Rendered CV**:
The A4, single-column, ATS-parseable PDF built from the Profile and the
reviewed outcome — full role history, only selected achievements, reviewed
text (decisions/0002).
_Avoid_: final CV, tailored profile, generated CV, output

**CV snapshot**:
The rendered CV's exact bytes, persisted once on the Application as
`cvSnapshot` and never mutated — the historical record of what was actually
sent.
_Avoid_: attachment, PDF copy, export file

**Save panel**:
The macOS file-save dialog that lands the rendered CV on disk at export,
receiving bytes identical to the CV snapshot (decisions/0003).
_Avoid_: share sheet, download

**Fit report**:
The post-export view of how the Profile met this JD: strength chips, gap
chips, and the rationale as New York prose.
_Avoid_: summary, scorecard, analysis

**Strength**:
One selected achievement as the fit report presents it — evidence the Profile
meets the job description, shown with its reviewed text. Derived from the
selection step, never re-derived from the JD.
_Avoid_: match, highlight, win

**CV template**:
The rendered CV's fixed visual identity — its own print palette and typefaces,
section order, and layout rules, deliberately distinct from the app's
trail-map design system (decisions/0007). There is exactly one template; it is
not user-selectable.
_Avoid_: theme, style preset, layout option

**Fit loop**:
The automatic ladder that lands the rendered CV on at most two A4 pages:
density compaction first, then condensing wordy bullets, then — as a last
resort — trimming the weakest selected items, with any trim noted in the fit
report. The renderer never silently drops selected content outside this loop.
_Avoid_: shrink-to-fit, autosize

**Fit metrics**:
The per-export record of what the fit loop saw and did — content volume,
settings applied, passes taken, page counts — kept so selection sizing can
learn what fits over time.
_Avoid_: telemetry, analytics
