---
key: CVEXPORT
---

# CV Export

Turn a reviewed outcome into the thing that actually gets sent. Export renders
the Profile and the reviewed outcome into an A4, single-column, ATS-parseable
PDF (`ImageRenderer`, per ARCHITECTURE.md's tech stack), persists the app's
first `Application` — the rendered CV as its immutable snapshot, the selection
rationale, status applied — hands the same bytes to a save panel, and shows
the fit report. This slice owns the `Application` model (roadmap-minimal,
decisions/0001), the rendered CV's content policy (decisions/0002), the
save-panel delivery (decisions/0003), and the fit report view. It closes
Phase 1: import → curated Profile → pasted JD → tailored PDF on disk.

The export consumes the tailor slice's reviewed outcome and never re-derives
anything from the job description: gaps, rationale, and the selection arrive
verbatim from the review. The Profile is read, never written.

Out of scope: the `Stage` model and pipeline board (Phase 2), Typst rendering
(a later upgrade), journey/stats export (Phase 5), editing the selection or
rewordings after review (tailoring owns review), and any change to tailoring
behaviour.

## [CVEXPORT-1] Exporting a reviewed outcome persists an Application carrying the rendered CV as its snapshot

The tracer criterion: reviewed outcome (plus the tailor sheet's job details
and the Profile) → rendered PDF → `Application` inserted with `cvSnapshot`
holding the PDF bytes. It proves the render seam, the model, the store, and
the wiring from the tailor review end to end.

Exercised with `FixtureIntelligenceService` driving a tailor run to review,
then exporting. The snapshot decodes as a PDF (PDFKit `PDFDocument` accepts
the bytes). `cvSnapshot` is written exactly once, at export — never mutated
afterwards (ARCHITECTURE.md invariant; decisions/0001).

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

The reviewed text: the accepted rephrasing, or the canonical
`Achievement.text` where the rephrasing was rejected ([TAILOR-13],
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

## [CVEXPORT-6] The rendered CV lists the Profile's skills

A skills section naming each of the Profile's `SkillTag`s — all of them, not
just those attached to selected achievements: skills are Profile-level canon,
and ATS keyword matching wants them present.

## [CVEXPORT-7] Every page of the rendered CV measures A4

595 × 842 points (±1pt for float rounding), every page, asserted via PDFKit
page bounds. Single-column layout is part of the same content policy
(decisions/0002) but is a visual-verify concern; the measurable clause is the
page size.

## [CVEXPORT-8] The persisted Application carries the tailor sheet's company, role title and job description

`JobDetails` flows from the tailor sheet into the Application fields verbatim
— company and role title stay the free-text labels they were on the sheet
([TAILOR-2] body); empty ones persist as empty strings.

## [CVEXPORT-9] The persisted Application stores the selection rationale verbatim

`cvSelectionRationale` equals the reviewed outcome's rationale character for
character — the transparency record [TAILOR-7] promised cv-export would
persist. Never summarised, trimmed, or re-derived.

## [CVEXPORT-10] An export creates the Application with status applied

Rendering and saving the CV is the act of applying — there is no draft state
in this slice (`ApplicationStatus` defines the full ARCHITECTURE.md §3 case
set, but export always writes `.applied`; the other cases wait for Phase 2's
pipeline board).

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

## [CVEXPORT-13] Exporting twice for the same job creates two Applications

No dedup and no refusal (settled at plan): re-tailoring the same JD is a
legitimate flow, and each export is its own historical record with its own
snapshot. Any merge/cleanup story belongs to the Phase 2 pipeline.

## [CVEXPORT-14] An export leaves the persisted Profile unchanged

The Profile is export's read-only input, extending [TAILOR-15] through the
export: after run, review, and export, the Profile's roles, achievements,
texts, and counts are unchanged — the only new persisted object is the
Application.

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
