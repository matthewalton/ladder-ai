---
key: CVEXPORT
---

# CV Export

Turn a reviewed outcome into the thing that actually gets sent, and let the
user rule on it first. The slice runs in two steps with the persistence
boundary between them (decisions/0009): **compose** renders the Profile and
the reviewed outcome into an A4, single-column, ATS-parseable PDF
(`ImageRenderer`, per ARCHITECTURE.md's tech stack) and writes nothing at all;
**export** attaches that rendered CV to the Application the tailor ran for
(decisions/0006) — the immutable snapshot, the selection rationale, the fit
metrics, a draft flipped to applied — and hands the same bytes to a save
panel. This slice owns the `Application` model (roadmap-minimal,
decisions/0001), the rendered CV's content policy (decisions/0002), the
save-panel delivery (decisions/0003), the fit report view, and the CV preview.
It closed Phase 1: import → curated Profile → JD → tailored PDF on disk.

Between the two steps sits the **CV preview**: the composed CV as it will
print, its fit report, its live coverage, its page count, and an editing
surface over it. The user rules on the CV before anything is written — adding
points the tailor passed over and dropping anything on the page but their own
name (decisions/0014), rewording bullets and the summary for this application
only (decisions/0010), and tagging what the model missed. Edits live for the
sitting and are never persisted (decisions/0013); an edited CV over two pages
is refused rather than machine-trimmed (decisions/0012).

The export consumes the tailor slice's reviewed outcome and never re-derives
anything from the job description: gaps, rationale, and the selection arrive
verbatim from the review, and the user's edits are the only other input. The
Profile is export's read-only input — the one write the preview can make to it
is a Tag the user applies ([CVEXPORT-54]), which is its own action and not
part of the export.

Since decisions/0007 the rendered CV follows the **CV template** — its own
print palette and bundled typefaces, deliberately outside the app's trail-map
design system — and the **fit loop** (decisions/0008) lands every export on
at most two block-paginated A4 pages, recording **fit metrics** as it goes
(this slice's CONTEXT.md defines all three). The loop's condense and trim
passes are tailor-owned service calls ([TAILOR-25], [TAILOR-26]); this slice
invokes them and renders what returns, rewording nothing itself.

Out of scope: the `Stage` model and pipeline board (Phase 2), Typst rendering
(rejected at the template decision — the styled SwiftUI render stays,
decisions/0007), journey/stats export (Phase 5), authoring brand-new points in
the preview (the Profile editor is the one place a point is born,
decisions/0010), persisting preview edits across sittings (decisions/0013 —
so this amendment carries no schema change, no migration, and no round-trip
criterion), Regenerate — recomposing from the preview, designed for by
decisions/0009 and deliberately not built here (Baton #199) — user-facing
template or fit settings (there is one template and the loop is automatic),
and learning selection budgets from fit metrics (deferred, Baton #162).

## [CVEXPORT-1] Exporting a reviewed outcome attaches the rendered CV to the application as its snapshot

The tracer criterion: reviewed outcome (plus the Profile) → rendered PDF →
the provided `Application`'s `cvSnapshot` holding the PDF bytes
(decisions/0006 — export attaches to the application the tailor ran for,
never inserts a fresh one). It proves the render seam, the model, the store,
and the wiring from the tailor review end to end.

Exercised with `FixtureIntelligenceService` driving a tailor run to review,
composing, then exporting into a pre-created draft Application. The snapshot
decodes as a PDF (PDFKit `PDFDocument` accepts the bytes). `cvSnapshot` is
written exactly once, at export — never mutated afterwards (ARCHITECTURE.md
invariant; decisions/0001); Create CV is not offered again once one exists
([PIPEBOARD-42]).

Since decisions/0009 this describes the **export** half specifically. The user
has already seen this CV in the preview ([CVEXPORT-36]); export is what they
trigger from it, and the only code path that writes the snapshot — write-once
by construction rather than by discipline.

## [CVEXPORT-2] The rendered CV contains the Profile's name, plus the headline and contact details the user has not removed

The identity header opens the document. Contact fields that are empty on the
Profile are simply omitted — no placeholder text. Asserted (like every content
criterion) by extracting text from the rendered PDF with PDFKit; the
extraction succeeding at all is the ATS-parseable guarantee — the CV is real
text, never a rasterised image.

Since decisions/0014 the header describes what the Profile holds *absent a
removal*: the headline and any contact line may be dropped for one application
([CVEXPORT-49]). The name is the exception and cannot be dropped at all
([CVEXPORT-50]).

## [CVEXPORT-3] The rendered CV lists every Role the user has not removed, with its title, company and dates

The default is to keep every Role, including one with no selected achievements:
employment history stays continuous so an ATS reading the CV detects no gaps.
Tailoring trims bullets, not jobs — nothing in the pipeline may drop a role,
not the tailor, not the fit loop, not the renderer. Only the user may, from the
preview ([CVEXPORT-46], decisions/0014), and that costs them the continuity
this criterion was written to protect: the ATS price was put to the human at
the plan stage and the wider control surface chosen deliberately.

Dates render at month resolution (matching the tailor payload's convention); a
current role (nil end) renders its end as "Present". Roles appear
newest-first, the same ordering the tailor payload uses.

## [CVEXPORT-4] Each selected achievement appears under its Role using the reviewed text

The reviewed text: the accepted expanded bullet, or the canonical brief
`Achievement.text` where the bullet was rejected ([TAILOR-13],
[TAILOR-14]). Grouping by Role requires achievement identity to travel with
the reviewed outcome — the tailor review already holds the `Achievement`
models, so the export seam receives the outcome with its achievements
resolvable to their Roles. A code-level touch in the tailor slice is fine;
no TAILOR criterion changes — the reviewed outcome's promised behaviour is
untouched.

## [CVEXPORT-5] An achievement outside the final selection does not appear in the rendered CV

Tailoring's whole point: the selection is the CV. A profile achievement
outside the selection — and whose text appears nowhere else — is absent from
the extracted text (decisions/0002).

The binding moved from the *service's* selection to the **final** one
(decisions/0010): the preview may add a point the tailor skipped
([CVEXPORT-41]) or drop one it chose ([CVEXPORT-42]), so what renders is the
selection as it stands when the CV is composed, not the tailor result's.

## [CVEXPORT-7] Every page of the rendered CV measures A4

595 × 842 points (±1pt for float rounding), every page, asserted via PDFKit
page bounds. Pages are composed by the block-aware pagination
([CVEXPORT-24]), no longer by slicing one tall view at fixed heights.
Single-column layout is part of the same content policy (decisions/0002) but
is a visual-verify concern; the measurable clause is the page size.

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

The flip belongs to the **export** half alone (decisions/0009): composing and
previewing a CV, however long the user spends editing it, leaves a draft a
draft ([CVEXPORT-35]). Applying is the user's explicit commit, not a side
effect of looking.

## [CVEXPORT-11] A fully-populated Application round-trips through a store reopen

The model-change persistence test CLAUDE.md requires, mirroring [PROFILE-5]:
an Application with every field populated (snapshot bytes included, and the
fit metrics record with every field non-default — [CVEXPORT-30],
decisions/0008) is byte-equal after closing and reopening the store on the
same on-disk container.

## [CVEXPORT-12] The saved PDF file is byte-identical to the persisted snapshot

One render, two destinations (decisions/0003): the bytes handed to the save
panel are the bytes on `cvSnapshot` — never a second render, which could
drift. Tested at the export seam (the document/data offered for saving),
not by driving the macOS panel.

Since decisions/0009 both destinations are fed by the render the preview last
showed, so it is one render, three sights: the pages on screen, the snapshot,
and the file. Editing re-lays-out and re-renders the composed document
([CVEXPORT-58]); export takes whatever that left standing and does not render
again.

## [CVEXPORT-22] Exporting into an application creates no new Application

Replaces [CVEXPORT-13]'s fresh-row-per-export stance (decisions/0006):
export sets `cvSnapshot` and `cvSelectionRationale` on exactly the provided
application — the rationale verbatim, [CVEXPORT-9]'s promise — and the
application count is unchanged afterwards. No dedup survives upstream:
importing the same posting twice still makes two Applications
([PIPEBOARD-35]), each with its own export.

Composing creates nothing either, which is the stronger promise
([CVEXPORT-35]): a user who composes three CVs and exports none leaves the
store exactly as they found it.

## [CVEXPORT-14] An export leaves the persisted Profile unchanged

The Profile is export's read-only input, extending [TAILOR-15] through the
export: after run, review, and export, the Profile's roles, achievements,
texts, and counts are unchanged — the only persisted change is on the
Application the export attached to.

This survives the preview literally (decisions/0010): rewording a bullet
writes no canon ([CVEXPORT-52]), and applying a Tag is the user's own action
with its own criterion ([CVEXPORT-54]) rather than something the export does.

## [CVEXPORT-15] The fit report lists every flagged gap

Gaps arrive verbatim from the reviewed outcome ([TAILOR-6] surfaced them) —
rendered as gap chips in the view. No gaps → no gap section, not an empty
frame.

Since decisions/0009 the report's home is the **preview**, not the
post-export screen: the content is unchanged, only the moment. The user reads
the gaps while they can still act on them ([CVEXPORT-37]).

## [CVEXPORT-16] The fit report lists each selected achievement as a strength

Strengths are derived from the selection step, not re-derived from the JD
(ARCHITECTURE.md Phase 1, item 4): one strength chip per selected
achievement, showing its reviewed text. Shown in the preview before the export
commits anything (decisions/0009), over the selection as it currently stands
— a point added in the preview is a strength like any other ([CVEXPORT-41]).

## [CVEXPORT-17] The fit report shows the selection rationale verbatim

The rationale as prose — set in New York (`Font.trailNarrative`, DESIGN.md
§3: narrative text is the story voice) — exactly as the service stated it,
shown in the preview rather than after the export (decisions/0009). Editing
never rewrites it: the rationale records what the service said about its own
selection, and stays that record even after the user changes the selection.
Font choice is a visual-verify concern; the measurable clause is the verbatim
rationale text.

## [CVEXPORT-18] The rendered CV lists every Education entry the user has not removed, verbatim and newest-first

Education is facts, not tailorable content ([TAILOR-19]): every entry renders
with qualification, institution, month-resolution dates (nil end as
"Present"), and the detail line when present. Newest-first by start date,
matching the roles convention.

Since decisions/0014 an entry may be dropped for one application
([CVEXPORT-47]) — the only per-application control over it, since nothing
here is rewordable. Absent a removal this is unchanged.

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

"The selection" here means the final one, as in [CVEXPORT-5]: the preview may
add a project the tailor skipped ([CVEXPORT-43]) or drop one it chose
([CVEXPORT-44]).

## [CVEXPORT-23] The rendered CV's skills section shows each named skill category with its skills

Replaces [CVEXPORT-6]'s flat skills line (Tailor decisions/0009; the id is
retired): the reviewed outcome carries the service's skill grouping
([TAILOR-24]), and the renderer draws the categorised table — category name
in template blue, its skills after it. The vocabulary bound survives from
decisions/0004: every skill shown comes from the selection's Tag union, so a
Tag on unselected content stays absent from the extracted text exactly as
before. The two-column arrangement is visual-verify; the measurable clause
is each category name appearing with its skills.

## [CVEXPORT-24] A page break never splits a text line

Block-aware pagination (decisions/0008) replaces the raw tall-view slicing
that could cut a line of text across the A4 boundary: layout composes
measured blocks — header, summary, role lines, bullets, section headers,
entries — and a break falls only between blocks. Asserted at the pagination
seam: every block's frame lands wholly inside one page's content box
([CVEXPORT-7] fixes the page metrics). A section header block never lands as
the last block on a page — it travels with its first following block.

## [CVEXPORT-25] A rendered CV never exceeds two pages

The fit loop's hard cap (decisions/0008). The ladder: density compaction
(template spacing tightened stepwise), then the condense pass
([TAILOR-25], [CVEXPORT-26]), then the trim pass ([TAILOR-26],
[CVEXPORT-27]) — repeated until the render fits. Exercised with an oversized
fixture Profile whose natural render exceeds two pages: the exported
snapshot's page count is at most 2. The "ideally fills two pages" half of
the rule is [CVEXPORT-29].

The ladder runs at compose time, over the tailor's own selection. On the
edited path the cap is upheld by a different mechanism (decisions/0012): the
loop never re-runs over hand-edited content ([CVEXPORT-61]) and an
over-length edit is refused at the export instead ([CVEXPORT-59]), so it
cannot reach the renderer at all. Either way no export exceeds two pages.

## [CVEXPORT-26] The fit loop sends a condense request only when compaction leaves the CV over two pages

Pass order is fixed and lazy (decisions/0008): content that fits after
density compaction alone produces an export with zero condense requests —
asserted via the fixture service's recorded requests. Over-length content
records exactly the passes it needed, in ladder order.

## [CVEXPORT-27] The fit loop sends a trim request only when a condensed CV still exceeds two pages

The terminal rung (decisions/0008): recorded requests show condense before
trim, and no trim request when condensing sufficed. A trim's removed items
are never silently gone — they surface via [CVEXPORT-28].

## [CVEXPORT-28] The fit report lists each item the fit loop trimmed

The trim list: the difference between the reviewed selection and the trim
pass's returned subset ([TAILOR-26]), each removed item named in the fit
report beside strengths and gaps. No trim → no trim section, the
[CVEXPORT-15] empty-section stance.

Since decisions/0009 the list appears in the preview, before the export
commits anything — which is what makes it actionable: the user can put a
trimmed item back ([CVEXPORT-41]) and cut something else instead. Only the
compose-time fit loop ever populates it; editing never adds to it
([CVEXPORT-61]).

## [CVEXPORT-29] A CV naturally filling more than one and a half pages renders with stretched spacing

The underflow half of "always two full pages when it can be"
(decisions/0008): when the natural render's content ends past the 1.5-page
threshold but short of two full pages, spacing stretches uniformly toward a
flush second page, capped at 1.25× — the cap wins over flushness, so a
render may legitimately end short of the bottom margin. At or under the
threshold, natural spacing renders unchanged — one strong page beats one
page plus a straggler. Thresholds and cap are template metrics in `CVTheme`;
asserted at the layout seam via the chosen stretch factor.

## [CVEXPORT-30] Each export persists its fit metrics

The per-export record (decisions/0008; this slice's CONTEXT.md): content
volume sent to render (role, bullet, project, skill counts and total
character count), settings applied (compaction step, stretch factor), passes
run (condense, trim, repair counts), and page counts (natural and final).
Persisted on the Application beside the snapshot — one export, one record,
written once. Feedstock for future selection budgets (Baton #162); this
slice only records. Round-trips under [CVEXPORT-11].

Written by the **export** half only (decisions/0009). A composed CV the user
abandons records nothing ([CVEXPORT-35]), so a discarded generation cannot
poison the content budget every later tailor run reads ([TAILOR-56],
[TAILOR-57]) — the reason the persistence boundary sits where it does.

## [CVEXPORT-31] A role's location and industry render on its subline

The grey meta subline beneath the role's title/company line, from the
Role's optional print fields (Profile decisions/0010, [PROFILE-22]): both
present → "location · industry"; one present → that one alone; both nil →
no subline at all — never an empty line. Colour and weight are
visual-verify; the measurable clause is presence and absence in the
extracted text.

## [CVEXPORT-32] A titled achievement's bullet opens with its title

Rendered "Title - description" (Profile decisions/0010): the canonical
`Achievement.title` verbatim — tailoring never writes it (root
`CONTEXT.md`) — then the hyphen separator, then the reviewed text exactly as
[CVEXPORT-4] promises it. A nil or empty title renders the reviewed text
alone, byte-for-byte what a pre-title export produced. The bold weight is
visual-verify; the measurable clause is the "title - text" ordering in the
extracted text.

## [CVEXPORT-33] The rendered CV lists the interests the user has not removed, in order

The closing section, entry order preserved ([PROFILE-14]). No interests →
no Interests section, the [CVEXPORT-21] stance. Interests were already in
the tailor payload as context ([TAILOR-19]); they render from the Profile
directly — nothing selects or rewords them, and since decisions/0014 the one
per-application control is dropping an interest from this CV
([CVEXPORT-48]).

## [CVEXPORT-34] The rendered CV embeds the template's bundled typefaces

The template's faces (decisions/0007): Inter for body text and Source Serif
4 Bold for the name header, both bundled in this slice and registered at
render time. Asserted via the PDF's embedded font names — the extracted
list contains Inter and Source Serif 4 and no system-font fallback for
body text. This guards the silent failure where registration breaks and
every glyph quietly renders in San Francisco. Palette hexes and metrics
are visual-verify.

## [CVEXPORT-35] When a CV is composed, nothing is written to the store

The persistence boundary (decisions/0009). Compose builds the document, runs
the fit loop and renders; it sets no `cvSnapshot`, no `cvSelectionRationale`,
no `fitMetrics`, flips no status, stamps no `appliedAt`, and inserts nothing.
Every other field on the Application survives character for character, and the
Application count is unchanged.

Composing is not free — the fit loop may still spend condense and trim calls
(decisions/0008), and composing twice costs twice. Cost is not persistence:
what a discarded composition must leave behind is nothing at all.

Asserted by composing (including a composition whose fit loop runs both
passes), then refetching the Application: every field equals its pre-compose
value.

## [CVEXPORT-36] The CV preview presents every page of the composed CV

The composed document as it will print — the rendered pages themselves, not a
second SwiftUI arrangement of the same content that could drift from what
exports. Asserted at the preview's model seam: the document it holds decodes
as a PDF whose page count and extracted text match the composed render, with
the Application still untouched ([CVEXPORT-35]). Page metrics stay
[CVEXPORT-7]'s promise. Zoom, scrolling, and how the pages are framed on
screen are visual-verify.

## [CVEXPORT-37] The fit report appears in the preview before anything is persisted

Strengths, gaps, rationale, and trimmed items ([CVEXPORT-15], [CVEXPORT-16],
[CVEXPORT-17], [CVEXPORT-28]) are shown as soon as the CV is composed. Their
content is unchanged; only the moment moved (decisions/0009). Before this, the
report described a decision already taken — the user first saw the CV after it
was on record, with no way back.

Asserted by composing and reading the preview's fit report while the
Application still has no snapshot, no rationale and no fit metrics.

## [CVEXPORT-38] Coverage splits the Match's matched Tags into those the selection carries and those nothing carries

Coverage (this slice's `CONTEXT.md`) is deterministic and built in Swift from
each point's **Overlap** with the confirmed Match's matched Tags (Tailor
`CONTEXT.md`), resolved case-insensitively through primary names and Aliases
like every other Tag comparison (root ADR 0005). The partition is total: every
matched Tag lands on exactly one side.

Worked example: a Match with 8 matched Tags, and a selection whose points
between them carry 5 of those Tags → 5 carried, 3 uncovered. Add a point
tagged with one of the 3 → 6 carried, 2 uncovered. A Tag on a point that is
not selected counts for nothing, and a Tag the Match never matched counts for
nothing either — coverage measures this CV against this Match, not against the
pool.

Keep the three numbers distinct in code and on screen: **Coverage** is
selection-wide and deterministic, the **Match score** is Profile-against-JD
([TAILOR-41], [CVEXPORT-40]), and **Overlap** is per-point.

## [CVEXPORT-39] When the selection changes, coverage recomputes without a service request

Deterministic and offline (decisions/0011), so it can run on every toggle
without putting the network in the middle of ticking a checkbox. Asserted
across a sequence of adds and removes with `FixtureIntelligenceService`: the
recorded requests are empty and each coverage reading matches the one a
fresh computation over that selection gives.

## [CVEXPORT-40] Editing the selection in the preview leaves the Match score unchanged

The guard root ADR 0005 demands. The Match score measures the Profile's Tag
vocabulary against the job description ([TAILOR-41]) — not this CV — so
adding, removing and rewording points move it not at all. Asserted explicitly:
the Application's Match score after a run of edits is the value it had before
them.

The number that responds to editing is coverage ([CVEXPORT-38]). The preview
must label the two distinctly or it teaches the user something false
(decisions/0011).

## [CVEXPORT-41] When an Achievement the tailor result skipped is added in the preview, it appears on the rendered CV

The selection surface reaches every Achievement on the Profile, not just the
tailor's picks (decisions/0010). An added Achievement renders under its own
Role, in that Role's own achievement order, using the canonical
`Achievement.text` — there is no rephrasing for a point the service never saw,
and the preview never invents one ([CVEXPORT-52]). Its title still leads the
bullet ([CVEXPORT-32]).

Adding the first bullet to a Role that had none turns a bare role line
([CVEXPORT-3]) into a role with content. Asserted by PDFKit text extraction,
this slice's content convention.

## [CVEXPORT-42] When a selected Achievement is removed in the preview, it leaves the rendered CV

Absent from the extracted text, the [CVEXPORT-5] stance now bound to the final
selection. The Role stays: removing its last bullet does not remove the job
([CVEXPORT-3]) — only an explicit role removal does ([CVEXPORT-46]).

## [CVEXPORT-43] When a Project the tailor result skipped is added in the preview, it appears on the rendered CV

It renders exactly as a service-selected project does ([CVEXPORT-21]) — name,
link when present, and its description as one prose block verbatim from the
Profile ([TAILOR-22], decisions/0005). A CV with no selected projects gains
its Projects section the moment the first project is added.

## [CVEXPORT-44] When a selected Project is removed in the preview, it leaves the rendered CV

Removing the last selected project removes the Projects heading with it — an
empty section is noise, [CVEXPORT-21]'s stance.

## [CVEXPORT-45] When a skill or a whole skill category is dropped in the preview, the skills table omits it

Dropping a category takes its skills with it; dropping the last skill in a
category removes that category's heading; dropping every category removes the
skills section, the same empty-section stance as [CVEXPORT-23] and
[CVEXPORT-21].

A dropped skill is a render decision for one CV and never a vocabulary edit:
the Tag stays on the Profile and on the point that evidences it, untouched
(root ADR 0005). Skill categories are per-CV and transient in the first place
([TAILOR-24], Tailor decisions/0009), so nothing persists either way.

## [CVEXPORT-46] When a whole Role is removed in the preview, the rendered CV omits that role

The deliberate exception to [CVEXPORT-3] (decisions/0014). The role's bullets
go with it, the remaining roles keep their newest-first order, and no
placeholder marks the hole.

This is the one preview edit that can cost the user a screen: an ATS reading
the CV may see the resulting employment gap and reject it. The cost was put to
the human at the plan stage and the wider control surface chosen. The preview
is the only place the consequence is visible, so it is the place to say so —
the removal control tells the user what dropping a role does before they do it.
Removal stays the user's explicit act; nothing in the pipeline may drop a
role.

## [CVEXPORT-47] When an Education entry is removed in the preview, the rendered CV omits it

Education is not rewordable (decisions/0014) — wrong wording is fixed in the
Profile editor — so whether an entry appears is the only per-application
control over it. What remains keeps [CVEXPORT-18]'s verbatim, newest-first
rendering; removing every entry removes the Education section.

## [CVEXPORT-48] When an interest is removed in the preview, the rendered CV omits it

What remains keeps its Profile entry order ([CVEXPORT-33]); removing every
interest removes the Interests section, the [CVEXPORT-21] stance.

## [CVEXPORT-49] When the headline or a contact line is removed in the preview, the identity header omits it

The header renders what the Profile holds minus what the user dropped — a
phone number withheld from one employer, a headline that suits every other
application but this one. [CVEXPORT-2] already omits empty Profile fields with
no placeholder, so a removal is indistinguishable from an empty field in the
extracted text. Neither is rewordable here (decisions/0014).

## [CVEXPORT-50] The Profile's name always appears on the rendered CV

The one element with no removal control (decisions/0014): a CV must identify
its author. No sequence of preview edits produces a nameless render, and the
preview offers no affordance to attempt one.

## [CVEXPORT-51] When a bullet is reworded in the preview, the rendered CV carries the reworded text

The reword surface covers a bullet's description. Its achievement title still
leads it verbatim from the Profile ([CVEXPORT-32]) — titles are canon and are
changed in the Profile editor, never here (decisions/0014). Asserted by PDFKit
extraction: the reworded text present, the text it replaced absent.

## [CVEXPORT-52] Rewording a bullet in the preview leaves the Profile's canonical achievement wording unchanged

`Achievement.text` and `.title` are canon (root `CONTEXT.md`). A preview
reword is a per-application wording, exactly as a **rephrasing** is (Tailor
`CONTEXT.md`), and it dies with the sitting (decisions/0013). Extends
[CVEXPORT-14] across the new surface: after composing, rewording several
bullets and exporting, every Achievement's text and title are character for
character what they were.

## [CVEXPORT-53] When the CV summary is reworded in the preview, the rendered CV carries the reworded summary

The summary is generated per tailor run and never stored on the Profile
([TAILOR-21], Tailor decisions/0006), so there is no canon to protect — a
reword changes this render and nothing else. It keeps its place under the
identity header ([CVEXPORT-20]), and rewording it to empty renders no empty
block, exactly as a blank generated summary does.

## [CVEXPORT-54] When a Tag is applied to a point from the preview, the Profile links that Tag to the point

How the user tells the model what it missed (decisions/0010). The write goes
through the Profile's own tagging operation — Profile owns it, along with the
case-insensitive resolution against primary names and Aliases; this slice
never mints a `SkillTag` of its own.

It is a **user action**, the only kind of Tag write there is (root ADR 0005 —
the LLM proposes, only the user writes), so it lands on the Profile
immediately rather than waiting for the export. That is why [CVEXPORT-14]
still holds literally: the *export* writes nothing to the Profile. A Tag the
confirmed Match already matched counts toward coverage at the next recompute
([CVEXPORT-38]).

## [CVEXPORT-55] A re-score refreshes the relevance stats over the edited selection in one request

One pass, on demand, after the user has finished editing — never per keystroke
(decisions/0011). Asserted via the fixture service's recorded requests:
exactly one re-score request for an edited selection of any size, carrying
every currently selected point, and the returned stats replacing the whole
set rather than merging into it.

The four stats and their 0–5 scale belong to the tailor slice ([TAILOR-59],
Tailor decisions/0017); this slice asks for them again over a selection the
tailor never saw. Like the tailor result's, they are transient — nothing here
persists them.

## [CVEXPORT-56] A point added in the preview reads as unscored until a re-score runs

Unscored is a state, never a zero (decisions/0011). A zero would read as
"judged and found worthless", which is a lie about a point nothing has judged
— and it would sit beside genuine zeros from the tailor's own scoring,
indistinguishable.

Asserted at the preview's model seam: an added point's relevance stats are
absent, and no code path substitutes a default. Presenting scored and unscored
points together on one screen is the preview's own problem to solve.

## [CVEXPORT-57] A failed re-score leaves the existing relevance stats and the composed CV unchanged

A re-score is a service call and can fail (decisions/0011) — a request error,
or a response still invalid after the single repair ([TAILOR-9]). Nothing is
half-applied: every previously scored point keeps its stats, every unscored
point stays unscored, and the composed document, its page count and its
coverage are untouched. The failure surfaces as a message the user can retry
from. Exercised with a fixture service that throws on the re-score request.

## [CVEXPORT-58] When an edit changes the composed CV's length, the preview's page count updates from a deterministic re-layout

Compaction and stretch only, no service calls (decisions/0012) — the same
offline property that lets coverage update live, so the count is instant. It
is the real block-paginated page count ([CVEXPORT-24]), not an estimate: the
number the export will be judged against ([CVEXPORT-59]) must be the number
the user sees.

Asserted at the layout seam across a sequence of edits that push the document
over two pages and back under, with the fixture service's recorded requests
staying empty throughout.

## [CVEXPORT-59] When the edited CV runs over two pages, export is refused

The two-page cap is absolute ([CVEXPORT-25]), and on the edited path it is
upheld by refusal rather than by the fit loop (decisions/0012): an over-length
edit never reaches the export at all. The preview says the CV is over and
roughly by how much; the user unticks or shortens something.

The user can strand themselves in an over-length state and must resolve it
before exporting. Accepted deliberately — an honest refusal beats silently
undoing their work. A refused export persists nothing, which composing had
already guaranteed ([CVEXPORT-35]).

## [CVEXPORT-60] An edited CV within two pages exports exactly as an unedited one does

One export path, not two (decisions/0009). Snapshot, verbatim rationale, fit
metrics, the draft→applied flip, then the save panel with bytes identical to
the snapshot — [CVEXPORT-1], [CVEXPORT-9], [CVEXPORT-10], [CVEXPORT-12] and
[CVEXPORT-30] all hold unchanged over an edited composition. The bytes
persisted are the render the preview last showed.

Exercised by editing a composition (an add, a removal and a reword), then
asserting the same post-conditions the unedited export asserts.

## [CVEXPORT-61] The fit loop's condense and trim passes never run over hand-edited content

Condensing and dropping what the user has just chosen is the opposite of
taking control (decisions/0012). The loop still runs at **compose** time over
the tailor's own selection, exactly as decisions/0008 describes; it is editing
that is protected from it, not composing.

Asserted via the fixture service's recorded requests: after the first edit, no
condense request and no trim request, however far over two pages the edit
takes the document — [CVEXPORT-59] is what happens instead. Deterministic
compaction and stretch still apply ([CVEXPORT-58]); they reword and drop
nothing.

## [CVEXPORT-62] Closing the preview with edits pending asks for confirmation first

The whole mitigation for edits that live only for the sitting
(decisions/0013): a long editing session lost to a mis-click is a real cost.
Confirmed, the edits are gone and the Application is untouched
([CVEXPORT-35]); cancelled, the preview stays exactly as it was, edits
included. A preview with no pending edits closes without asking.

Discarded edits do not come back. The next composition starts from the Profile
and the tailor result again — including removals (decisions/0014).

## [CVEXPORT-63] A Tag applied in the preview survives discarding the preview's edits

Tags are Profile writes that land immediately ([CVEXPORT-54]), never part of
the in-memory edit set (decisions/0013). Correct on purpose: the model should
learn what it missed whether or not this particular CV ships. Asserted by
applying a Tag, discarding at close, and reading the Tag back off the
Profile's pool and off the point it was applied to.
