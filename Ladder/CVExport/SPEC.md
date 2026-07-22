---
key: CVEXPORT
---

# CV Export

Turn a reviewed outcome into the thing that actually gets sent. Export renders
the Profile and the reviewed outcome into an A4, single-column, ATS-parseable
PDF (`ImageRenderer`, per ARCHITECTURE.md's tech stack), attaches it to the
Application the tailor ran for (decisions/0006) — the rendered CV as its
immutable snapshot, the selection rationale, a draft flipped to applied —
hands the same bytes to a save panel, and shows the fit report. This slice
owns the `Application` model (roadmap-minimal, decisions/0001), the rendered
CV's content policy (decisions/0002), the save-panel delivery
(decisions/0003), and the fit report view. It closed Phase 1: import →
curated Profile → JD → tailored PDF on disk.

The export consumes the tailor slice's reviewed outcome and never re-derives
anything from the job description: gaps, rationale, and the selection arrive
verbatim from the review. The Profile is read, never written.

Out of scope: the `Stage` model and pipeline board (Phase 2), Typst rendering
(a later upgrade), journey/stats export (Phase 5), editing the selection or
rewordings after review (tailoring owns review), and any change to tailoring
behaviour.

## [CVEXPORT-1] Exporting a reviewed outcome attaches the rendered CV to the application as its snapshot

The tracer criterion: reviewed outcome (plus the Profile) → rendered PDF →
the provided `Application`'s `cvSnapshot` holding the PDF bytes
(decisions/0006 — export attaches to the application the tailor ran for,
never inserts a fresh one). It proves the render seam, the model, the store,
and the wiring from the tailor review end to end.

Exercised with `FixtureIntelligenceService` driving a tailor run to review,
then exporting into a pre-created draft Application. The snapshot decodes as
a PDF (PDFKit `PDFDocument` accepts the bytes). `cvSnapshot` is written
exactly once, at export — never mutated afterwards (ARCHITECTURE.md
invariant; decisions/0001); Create CV is not offered again once one exists
([PIPEBOARD-42]).

## [CVEXPORT-2] The rendered CV contains the Profile's name, headline and contact details

The identity header opens the document. Contact fields that are empty on the
Profile are simply omitted — no placeholder text. Asserted (like every content
criterion) by extracting text from the rendered PDF with PDFKit; the
extraction succeeding at all is the ATS-parseable guarantee — the CV is real
text, never a rasterised image.

## [CVEXPORT-3] The rendered CV lists every Role with its title, company and dates

Every Role appears, including one with no selected achievements — employment
history stays continuous for ATS gap detection; tailoring trims bullets, not
jobs. Dates render at month resolution (matching the tailor payload's
convention); a current role (nil end) renders its end as "Present". Roles
appear newest-first, the same ordering the tailor payload uses.

## [CVEXPORT-4] Each selected achievement appears under its Role using the reviewed text

The reviewed text: the accepted expanded bullet, or the canonical brief
`Achievement.text` where the bullet was rejected ([TAILOR-13],
[TAILOR-14]). Grouping by Role requires achievement identity to travel with
the reviewed outcome — the tailor review already holds the `Achievement`
models, so the export seam receives the outcome with its achievements
resolvable to their Roles. A code-level touch in the tailor slice is fine;
no TAILOR criterion changes — the reviewed outcome's promised behaviour is
untouched.

## [CVEXPORT-5] An achievement outside the selection does not appear in the rendered CV

Tailoring's whole point: the selection is the CV. A profile achievement the
service did not select — and whose text appears nowhere else — is absent from
the extracted text (decisions/0002).

## [CVEXPORT-6] The rendered CV's skills line is the union of the selected content's Tags

Derived per application (decisions/0004): the sorted unique union of Tag names
across the selected achievements and the selected projects (decisions/0005).
A Tag attached only to unselected content stays off the CV; `profile.skills`
as a whole is never dumped. Tags exist to map content to the job description,
so the skills line is exactly the vocabulary this application's selection
earned.

## [CVEXPORT-7] Every page of the rendered CV measures A4

595 × 842 points (±1pt for float rounding), every page, asserted via PDFKit
page bounds. Single-column layout is part of the same content policy
(decisions/0002) but is a visual-verify concern; the measurable clause is the
page size.

## [CVEXPORT-8] An export leaves the application's company, role title and job description untouched

Since decisions/0006 those fields already live on the Application — written
at import ([PIPEBOARD-35]) or by the detail's editors — and the tailor read
them from there ([TAILOR-23]). Export writes only its own fields
(`cvSnapshot`, `cvSelectionRationale`, the status flip and stamp,
[CVEXPORT-10]); the job details survive an export character for character.

## [CVEXPORT-9] The persisted Application stores the selection rationale verbatim

`cvSelectionRationale` equals the reviewed outcome's rationale character for
character — the transparency record [TAILOR-7] promised cv-export would
persist. Never summarised, trimmed, or re-derived.

## [CVEXPORT-10] An export flips a draft application to applied and stamps its applied date

Rendering and saving the CV is the act of applying (decisions/0006): a
`.draft` application becomes `.applied` at export, `appliedAt` stamped
`.now` only when nil — an existing date is never overwritten, the
[PIPEBOARD-9] stance. An application already past draft keeps its status and
date untouched.

## [CVEXPORT-11] A fully-populated Application round-trips through a store reopen

The model-change persistence test CLAUDE.md requires, mirroring [PROFILE-5]:
an Application with every field populated (snapshot bytes included) is
byte-equal after closing and reopening the store on the same on-disk
container.

## [CVEXPORT-12] The saved PDF file is byte-identical to the persisted snapshot

One render, two destinations (decisions/0003): the bytes handed to the save
panel are the bytes on `cvSnapshot` — never a second render, which could
drift. Tested at the export seam (the document/data offered for saving),
not by driving the macOS panel.

## [CVEXPORT-22] Exporting into an application creates no new Application

Replaces [CVEXPORT-13]'s fresh-row-per-export stance (decisions/0006):
export sets `cvSnapshot` and `cvSelectionRationale` on exactly the provided
application — the rationale verbatim, [CVEXPORT-9]'s promise — and the
application count is unchanged afterwards. No dedup survives upstream:
importing the same posting twice still makes two Applications
([PIPEBOARD-35]), each with its own export.

## [CVEXPORT-14] An export leaves the persisted Profile unchanged

The Profile is export's read-only input, extending [TAILOR-15] through the
export: after run, review, and export, the Profile's roles, achievements,
texts, and counts are unchanged — the only persisted change is on the
Application the export attached to.

## [CVEXPORT-15] The fit report lists every flagged gap

Gaps arrive verbatim from the reviewed outcome ([TAILOR-6] surfaced them; the
fit report is their post-export home) — rendered as gap chips in the view. No
gaps → no gap section, not an empty frame.

## [CVEXPORT-16] The fit report lists each selected achievement as a strength

Strengths are derived from the selection step, not re-derived from the JD
(ARCHITECTURE.md Phase 1, item 4): one strength chip per selected
achievement, showing its reviewed text.

## [CVEXPORT-17] The fit report shows the selection rationale verbatim

The rationale as prose — set in New York (`Font.trailNarrative`, DESIGN.md
§3: narrative text is the story voice) — exactly as the service stated it.
Font choice is a visual-verify concern; the measurable clause is the verbatim
rationale text.

## [CVEXPORT-18] The rendered CV lists every Education entry verbatim, newest-first

Education is facts, not selectable content ([TAILOR-19]): every entry renders
with qualification, institution, month-resolution dates (nil end as
"Present"), and the detail line when present. Newest-first by start date,
matching the roles convention.

## [CVEXPORT-20] The rendered CV shows the reviewed outcome's summary under the identity header

The generated CV summary (Tailor decisions/0006, [TAILOR-21]) opens the
document body, between the identity header and the first role — verbatim,
asserted via PDFKit text extraction like every content criterion. It lives
only inside this application's rendered snapshot; the Profile stays
summary-free. A defensive blank summary renders no empty block.

## [CVEXPORT-21] A project appears on the rendered CV only when the selection includes it

Replaces [CVEXPORT-19]'s per-point rule (decisions/0005; Tailor
decisions/0007). Projects are optional colour, unlike roles ([CVEXPORT-3]
keeps every role for employment continuity). A selected project renders —
name, link when present, and its description as one prose block, verbatim
from the Profile ([TAILOR-22]); an empty Projects heading is noise, so no
selected projects means no Projects section.
