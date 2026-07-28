# CV Export — language

Slice-local terms. `Profile`, `Role`, `Achievement`, `Application`, `Tag`, and
`Tailoring` are defined in the root `CONTEXT.md`; `reviewed outcome`, `gap`,
`rationale`, `rephrasing`, `overlap`, and `relevance stats` in
`Ladder/Features/Tailor/CONTEXT.md`. None is restated here.

**Compose**:
Building the document, running the fit loop, and rendering — producing the CV
the preview shows. Composing persists nothing (decisions/0009); a composed CV
the user abandons leaves no trace.
_Avoid_: pre-export, dry run, provisional export

**Export**:
The slice's one persisting action: attach the rendered CV to the Application
(snapshot, rationale, fit metrics, status applied) and offer the save panel.
One render feeds both destinations. The user's explicit commit, taken from the
preview.
_Avoid_: submit, apply, send, generate

**CV preview**:
The screen between the tailor review and the export: the composed CV as it
will print, its coverage, its page count, and the editing surface over it
(decisions/0010). What the user rules on before anything is written.
_Avoid_: draft, proof, mockup, preflight

**Coverage**:
How much of the confirmed Match the current selection carries — the matched
Tags at least one selected point overlaps, and the matched Tags none does.
Deterministic and recomputed live as the selection changes (decisions/0011),
built from the per-point **Overlap** the tailor slice defines. Distinct from
the **Match score**, which measures the Profile against the job description and
never moves with editing.
_Avoid_: match score, fit, coverage score, alignment

**Re-score**:
The single on-demand service pass that refreshes the **relevance stats** (Tailor
`CONTEXT.md`) over the selection as the preview left it — one request, run when
the user asks, never per edit (decisions/0011). A point the pass has not
covered is **unscored**, a state distinct from a score of zero.
_Avoid_: re-rank, refresh scores, re-run, live scoring

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
How the Profile met this JD: strength chips, gap chips, and the rationale as
New York prose. Shown in the preview, before the export commits anything
(decisions/0009) — its content is unchanged, only its moment.
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
