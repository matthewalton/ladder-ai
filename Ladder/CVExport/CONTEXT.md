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
