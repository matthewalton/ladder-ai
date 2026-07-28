---
key: PIPEBOARD
---

# Pipeline Board

The Phase 2 foundation: the `Stage` model, the `Application` schema growth
(`source`, `appliedAt`, `notes`, `stages`), the status transition map, the
applications board grouped by status with drag between columns, Stage CRUD on
the application detail, and the app shell's growth from a single Profile
window to Profile/Applications sections. calendar-sync and timeline build on
what this slice persists.

The `Application` model is migrated in place in `Ladder/Features/CVExport/src/`
(decisions/0001) — cv-export's observable contract does not change, and its
[CVEXPORT-11] round-trip stays green throughout. `Stage` stores its kind as a
raw string (decisions/0002); the transition map and auto-advance rules are
decisions/0003. Since decisions/0008 the board owns the app's one creation
door: importing a job posting — a pasted link or a PDF — whose text the
intelligence service structures into company, role title and job
description, landing a draft Application with no typing. The manual add
(decisions/0004) and the standalone tailor entry (decisions/0007) are
superseded by that hero action; cv-export's export attaches the CV to the
created application ([CVEXPORT-22]) and stays the only path that attaches
one. The application detail also owns the job description after creation:
editing it in place and the JD re-import (decisions/0005), which extracts a
PDF or docx file's text on-device via the shared extractor — or fetches a
pasted link and extracts the page's text the same way (decisions/0006, both
now scoped to re-import: raw text, no LLM). The detail forms' long-text
fields — job description, notes, prep context — collapse to indicator rows
when set (docs/adr/0003), each row identifying the content it holds by its
opening words and its length (docs/adr/0006). Since decisions/0009 the detail also carries the
Match section: the persisted Match's score, matched Tags and vocabulary
gaps, with Scan JD — the on-demand door into the JD scan and Match review
that the tailor flow otherwise reaches first (root CONTEXT.md's "and on
demand" promise). The scan machinery and the review's semantics stay
Tailor-owned ([TAILOR-27]–[TAILOR-42], [TAILOR-46]–[TAILOR-51]); this slice
owns only the door and the summary.

Out of scope: calendar matching (the calendar-sync slice consumes the
`calendarEventID` and `meetingURL` fields this slice only stores), the
per-application timeline view, `prepPack`/`transcript`/`debrief` (Phase 3–4
gated models that do not exist yet), and any change to cv-export or tailoring
behaviour. The CV preview's JD-alignment stats and per-point LLM-judged
relevance stats are later tickets, not this slice.

## [PIPEBOARD-1] A Stage added to an exported Application survives an app relaunch

The tracer: fixture tailor run → export on an on-disk store →
`PipelineStore.addStage` → close and reopen the container. The Application
still has the Stage with its chosen kind, and its `cvSnapshot` is
byte-identical to the exported bytes. Proves the model, the relationship, the
schema registration (`Stage.self` in `ProfileStore.container`), and the store
in one line.

## [PIPEBOARD-2] A Phase 1 Application survives the schema migration with its CV snapshot byte-identical

ROADMAP Phase 2 exit criterion 2, pulled into the slice. The test copies the
committed Phase 1 fixture store (`LadderTests/Fixtures/Phase1Store/`,
generated from the pre-change HEAD — sidecar `-wal`/`-shm` files included) to
a temp URL and opens it with `ProfileStore.container(at:)` under the new
schema: the Application is present with every Phase 1 field value exact,
snapshot bytes byte-equal, and the new fields at their defaults (`notes ==
""`, `source == nil`, `stages` empty). The fixture's Profile/Role/
Achievement/SkillTag rows survive too. This is the criterion that defends the
`notes` declaration-default subtlety: lightweight migration populates
existing rows from the property's declaration initial value, so a default
that lives only in `init` fails exactly here.

## [PIPEBOARD-3] A fully-populated Stage round-trips through a store reopen

The model-change persistence test CLAUDE.md requires, mirroring
[CVEXPORT-11]: every Stage field populated — an `.other("Founder chat")`
kind, `scheduledAt`, `calendarEventID`, `meetingURL`, `prepContext`, a
non-pending outcome, `heardBackAt`, `sortIndex` — value-equal after closing
and reopening the store on the same on-disk container.

## [PIPEBOARD-4] The board shows each Application in the column matching its status

One column per `ApplicationStatus`, all six always present (empty ones
included); within a column, cards order newest-first by `appliedAt ??
createdAt`. The measurable clause is the store's grouping
(`applications(in:)`) including that ordering; column layout and chrome are
visual-verify.

## [PIPEBOARD-5] Moving an Application along a legal transition updates its persisted status

Board drag is the UI for this; the behaviour lives in
`PipelineStore.move(_:to:)` and the new status survives a store reopen. The
legal map is decisions/0003. A same-status drop is a no-op, not an error.

## [PIPEBOARD-6] Moving an Application along an illegal transition leaves its status unchanged

The store throws `PipelineStoreError.illegalTransition(from:to:)` and the
Application keeps its status — e.g. rejected → offer, applied → draft. The
board only offers legal drop targets (`canMove`), so the throw is the seam's
guarantee, not the UI's.

## [PIPEBOARD-7] Adding the first Stage to an applied Application advances it to active

Only the first Stage, and only from `.applied` (decisions/0003): adding a
Stage to an Application that is already active — or in any other status —
changes no status, and neither does a second Stage.

## [PIPEBOARD-8] Loading backfills the applied date on applied Applications that lack one

Phase 1 rows were exported straight to `.applied` with no `appliedAt` field;
their export moment was their creation moment, so `appliedAt = createdAt` is
accurate. Runs in `PipelineStore.load()`, idempotent — a second load changes
nothing, and Applications with an `appliedAt` are never touched.

## [PIPEBOARD-9] Moving a draft Application to applied stamps its applied date

`appliedAt = .now` when nil; an existing `appliedAt` is never overwritten
(re-entering applied after a withdrawn→… path does not exist in the map, but
the guard holds regardless).

## [PIPEBOARD-10] Stages keep their added order across a store reopen

SwiftData to-many relationships are unordered; `sortIndex` carries the order
(the [PROFILE-7] pattern) and `orderedStages` is the sorted read. Add three
Stages, reopen, the order is the added order.

## [PIPEBOARD-11] Deleting an Application removes its Stages with it

The cascade delete rule, proven by a fetch: after deleting an Application
with Stages, a `Stage` fetch returns no orphans. Deleting a single Stage via
`deleteStage` removes just that Stage — asserted in the same test's first
act.

## [PIPEBOARD-12] Source and notes edits on the application detail persist across a store reopen

`updateDetails` writes `source`/`notes` (and an explicit `appliedAt` edit)
and saves immediately, per the slice store convention.

## [PIPEBOARD-13] An application card derives its next waypoint from its earliest pending Stage

The lowest-`sortIndex` Stage with outcome `.pending`; nil when none — the
card then shows no waypoint chip. A pure helper (`nextWaypoint(for:)`) so the
derivation is testable without views. "Next waypoint" is the card's narrative
footer label (DESIGN.md §6); the code type stays `Stage` (root CONTEXT.md).

## [PIPEBOARD-14] The app shell switches between the Profile and Applications sections

The shell offers both sections and the board renders under Applications; the
Profile slice keeps its window unchanged under Profile. The measurable clause
is that both section roots render and the selection state switches; native
tab feel, toolbars, and the empty state (contour background + one New York
line) are visual-verify.

## [PIPEBOARD-15] Stage edits persist across a store reopen

`updateStage` covers the editable fields — kind, `scheduledAt`, outcome,
`heardBackAt`, `prepContext`, `meetingURL` — and the edited values survive a
close and reopen.

## [PIPEBOARD-16] An application card derives its days on trail from its applied date

`daysOnTrail(for:asOf:)` counts whole days from `appliedAt ?? createdAt` to
`asOf` — the parameter keeps the test deterministic. Rendered as the card's
quiet elapsed-time footer ("12 days on trail", DESIGN.md §6); no progress
bars, no percentages — that absence is visual-verify.

## [PIPEBOARD-21] Job-description edits on the application detail persist across a store reopen

`updateDetails` grows a `jobDescription` parameter, the [PIPEBOARD-12]
pattern: write and save immediately, values survive a close and reopen.
Until this criterion the Tailor export was the only writer — a manually
added Application ([PIPEBOARD-17]) carried an empty job description forever,
starving the prep-pack input guard ([PREP-5]) and the debrief payload. The
detail form gains a job-description editor section; its chrome is
visual-verify. Since [PIPEBOARD-29] the inline editor renders only while the
job description is empty — a set JD is changed by re-import or by remove and
retype (docs/adr/0003).

## [PIPEBOARD-22] Importing a PDF job description file replaces the Application's job description with its extracted text

The JD import (decisions/0005): pick a PDF on the application detail, the
shared extractor turns it into plain text entirely on-device, and that text
— raw, no LLM cleanup, no structuring — becomes the Application's
`jobDescription`, persisted through the store. The user tidies artefacts in
the editor ([PIPEBOARD-21]) if they care to.

## [PIPEBOARD-23] Importing a docx job description file replaces the Application's job description with its extracted text

Same path as [PIPEBOARD-22] through the docx branch of the shared extractor
(Office Open XML reading) — JDs are shared as Word files often enough that
the free second format is worth its own claim, the [CVIMPORT-1]/[CVIMPORT-2]
split.

## [PIPEBOARD-24] A failed job-description import leaves the job description unchanged

Every failure mode, file and link alike: a file with no extractable text (an
image-only PDF), a file that is neither PDF nor docx, a link that cannot be
fetched, and a fetched page whose text extracts to nothing. The existing
`jobDescription` value — empty or not — is untouched, and the failure is
reported next to the import affordance; the message chrome is visual-verify.

## [PIPEBOARD-25] A job-description import onto a non-empty job description requires confirmation before replacing it

Protects a Tailor-written JD from a mis-click: when the existing
`jobDescription` is non-empty the import waits for an explicit confirm;
declining changes nothing. Onto an empty job description the import lands
without a confirmation step. The rule is source-agnostic — the file and link
paths share it. The needs-confirmation decision is a pure helper so the rule
is testable without views; the dialog chrome is visual-verify.

## [PIPEBOARD-26] Importing a job description link replaces the Application's job description with the page's extracted text

The link path (decisions/0006, superseding decisions/0005's out-of-scope
line): paste a URL, a plain fetch pulls the page, and on-device HTML→text
conversion — no WebKit render, no LLM — lands the result raw as the
`jobDescription`. Server-rendered job pages (Greenhouse, Lever, Ashby…) are
the target; JS-only or auth-walled pages fail or land junk, and the editor
([PIPEBOARD-21]) is the correction path. The fetch is injected into the
store so tests run offline. The link itself is not stored anywhere.

## [PIPEBOARD-27] Importing a job description link that serves a PDF replaces the job description with the PDF's extracted text

Some postings link straight to a PDF. The fetched bytes are sniffed
(`%PDF` magic) and extracted via PDFKit instead of the HTML path — the
[PIPEBOARD-22] outcome through the link route.

## [PIPEBOARD-28] A job description link whose page embeds JobPosting structured data imports the posting's description text

Born from a real failure: Ashby-class SPA postings render an empty JS shell
— whole-page extraction finds nothing — but embed a schema.org `JobPosting`
`application/ld+json` block for search engines carrying the full
description. When any ld+json block on the page yields a JobPosting (top
level, in an array, or under `@graph`), its description — prefixed with the
posting's title and hiring organisation when present — becomes the JD,
converted HTML→text on-device. Preferred over whole-page text even on
server-rendered pages: it is the posting without the nav and footer. Pages
without one fall back to whole-page extraction ([PIPEBOARD-26]).

## [PIPEBOARD-29] A non-empty long-text field collapses to an indicator row when its form appears

The docs/adr/0003 pattern on this slice's three long-text fields: the job
description and the notes on the application detail, the prep context on the
Stage form. Set means non-empty after trimming whitespace. The indicator row
identifies the content it stands for — the start of the text
([PIPEBOARD-50]) and how much of it there is ([PIPEBOARD-49]) — and offers
the open affordance ([PIPEBOARD-31], [PIPEBOARD-32]) and Remove
([PIPEBOARD-33]); the text itself never renders inline — the Granola stance
([TRANSCRIPT-28]'s section). The set/collapsed decision is a pure helper so
the rule is testable without views; row chrome is visual-verify.

Amended by docs/adr/0006. The row used to carry nothing but the fact of
being set — "Job description set" — which reads as a status flag, so an
imported posting made the section look empty (ticket #201) even though every
gate keyed off the stored JD fired. What collapses, and when, is unchanged:
collapse still happens at any set content, decided at appearance, and a
length threshold was considered and declined (it would return the variable
form height docs/adr/0003 existed to stop). Only what the row then shows is
amended, and only for these three typed-or-imported fields — the debrief,
the prep pack and the Granola notes keep identifying themselves by the date
they were made.

## [PIPEBOARD-30] A long-text field that is empty when its form appears keeps its inline editor

The flip side of [PIPEBOARD-29]: entering text stays cheap. The collapse
decision is made at appearance, so an initially-empty field never collapses
mid-typing; the indicator appears on the next visit. The job description's
empty state keeps the import menu beside the editor
([PIPEBOARD-22]–[PIPEBOARD-28] unchanged).

## [PIPEBOARD-31] Opening the job description shows its text in a read-only window

Open follows Granola: `openWindow` carrying the Application's persistent ID;
the window renders the job description with text selection enabled, and shows
a gone message when the Application no longer resolves. Read-only is
deliberate (docs/adr/0003): the JD has alternate input paths — re-import
([PIPEBOARD-25]'s confirmation still guards it), or remove and retype — so
the window never edits. The indicator row's affordance says so: it reads
**View**, not Open (docs/adr/0006) — Open promised an edit this window has
never offered, and the row is the only place that promise is made. Window
chrome is visual-verify.

## [PIPEBOARD-32] Opening the notes or the prep context shows the text in an editable window

Typing is these fields' only input path (docs/adr/0003), so their window
edits, autosaving through the existing store seams — `updateDetails` for the
notes ([PIPEBOARD-12]), `updateStage` for the prep context ([PIPEBOARD-15]) —
never a private write path. Their indicator rows keep **Open**: the
affordance matches what the window does, which is why the job description's
reads View instead ([PIPEBOARD-31], docs/adr/0006). Window chrome is
visual-verify.

## [PIPEBOARD-33] Removing a long-text field's content requires confirmation before clearing it

All three fields. Confirming clears the value to empty through the store and
saves; the field then shows its inline editor again ([PIPEBOARD-30]).
Declining changes nothing. Confirmation everywhere is docs/adr/0003's rule —
hand-typed notes are as costly to recreate as generated content; only Granola
notes stay one-click, in their own slice. The needs-confirmation stance
mirrors [PIPEBOARD-25]; the dialog chrome is visual-verify.

## [PIPEBOARD-49] A long-text field's indicator row reports how many words the field holds

The size half of docs/adr/0006's "start and size". Words, not characters: a
posting is something a reader can picture at 1,200 words, and a character
count is a number nobody has an intuition for. A word is a
whitespace-separated run of the trimmed content, so the count survives the
newline noise a PDF extraction carries — `"Senior iOS Engineer\n\nAcme,
London"` is five words, because the blank line between them is one run of
whitespace and not a word of its own.

The label follows the shape the generated rows already use — the field's
name, an em dash, the fact that identifies the content — so the job
description reads "Job description — 1,240 words", the notes "Notes — 86
words", the prep context "Prep context — 210 words". A count of one is
singular: "Notes — 1 word". Thousands group by the user's locale, the way
every other number in the app does.

A pure helper beside `collapsesAtAppearance` in
`src/LongText/LongTextField.swift` derives the label (docs/adr/0006), so the
count is testable without views; the row's typography is visual-verify.

## [PIPEBOARD-50] A long-text field's indicator row shows the start of the text it holds

The snippet half of docs/adr/0006's "start and size", and the half that
answers the question the old row could not: is this the right posting. It is
the row's second line, beneath the label ([PIPEBOARD-49]), so it has the
row's full width.

The rule, contractually: take the content trimmed, collapse every run of
whitespace — the newlines a PDF extraction is full of included — to a single
space, then take the first 80 characters, cut back to the last whole word
that fits, and close with an ellipsis. Eighty is about one line at the row's
callout size in the detail form, and the cut at a word boundary keeps it
from ending mid-word. Content of 80 characters or fewer once normalised
shows whole, with no ellipsis. Worked: `"Senior iOS Engineer\n\nAcme,
London. We are looking for someone to own our design system end to end."`
normalises to 97 characters, whose first 80 end mid-word at "design s", so
the snippet is "Senior iOS Engineer Acme, London. We are looking for someone
to own our design…" — 78 characters plus the ellipsis.

A job description extracted from a whole page opens with whatever the
extraction stored, which may be nav text or a cookie line. The row reports
that truthfully; making the extraction open at the posting is
[PIPEBOARD-26]–[PIPEBOARD-28]'s job, not the row's (docs/adr/0006).

Derived by the same pure helper as [PIPEBOARD-49], so the truncation rule is
testable without views.

## [PIPEBOARD-35] Importing a job-posting link creates a draft Application with LLM-structured details

The tracer of the import-first creation (decisions/0008), replacing the
manual add's [PIPEBOARD-17]/[PIPEBOARD-18] and absorbing [PIPEBOARD-19]'s
guarantees: paste a posting link into the import surface, the fetched page's
text is structured by the intelligence service into company, role title and
job description, and a draft Application lands on the board with no typing —
fields from the extraction, `source` carrying the pasted URL (superseding
decisions/0006's "the link is not stored" for the creation path), status
`.draft` with `appliedAt` nil, and no CV fields (export stays the only path
that attaches one, [CVEXPORT-22]). A fresh context sees the row, so creation
saved. The creation seam (`PipelineStore.createApplication`) still refuses a
blank company or role title — whitespace-only counts as blank — and no dedup
applies: importing the same posting twice is two Applications.

Exercised with an injected fetch and `FixtureIntelligenceService` returning
the canned job-details result.

## [PIPEBOARD-36] Importing a job-posting PDF file creates a draft Application the same way

The file door of the import (decisions/0008): pick or drop a PDF of the
posting; the shared extractor pulls its text on-device and the same LLM
structuring lands the same draft Application, `source` carrying the file's
name. The sample-cv fixture doubles as the posting file — the import never
inspects what the text says, only that it extracts (the [PIPEBOARD-22]
stance).

## [PIPEBOARD-37] A link whose page embeds JobPosting structured data feeds the posting text to the extraction

[PIPEBOARD-28]'s pre-cleaning applied to creation: when the fetched page
carries a schema.org JobPosting ld+json block, the block's title,
organisation and description — not the whole-page text — are what the
intelligence service receives, so Ashby-class JS shells import and the
payload is the posting without the nav and footer. Asserted via the fixture
service's recorded payload. Pages without one fall back to whole-page
extraction.

## [PIPEBOARD-38] A failed job-posting import creates no Application

Every failure mode: a link that is not a valid http(s) URL (refused by the
sheet's pure helper before any store call), a fetch failure, a page or file
with no extractable text, a missing API key — refused before any fetch or
service call, the [TAILOR-4] stance — and a response still invalid after the
single repair ([PIPEBOARD-39]). The board's application count is unchanged;
there is no partial Application. The failure is reported in the import
sheet; message chrome is visual-verify.

## [PIPEBOARD-39] An invalid extraction response gets exactly one repair request

The Tailor decisions/0004 loop adopted for the import: a response failing
the job-details schema — or carrying a blank required field — triggers one
repair request carrying the original payload, the invalid response, and the
failure reason. An invalid-then-valid sequence records two requests, never
three; a second failure fails the import with nothing created.

## [PIPEBOARD-40] The extraction request carries the versioned job-details prompt

`Prompts/job-details.md` is born here: canonical, versioned, loaded at
runtime — never an inline string (the [TAILOR-5] stance). The fixture
service records the request it receives: the recorded prompt equals the
file's content, and the recorded payload carries the posting's text.

## [PIPEBOARD-41] The import surface opens from the empty state and the shell toolbar

The board's single hero action — "Create Application" — replaces
[PIPEBOARD-20]'s add form and [PIPEBOARD-34]'s standalone tailor entry in
both hosts: one prominent affordance in the Applications shell toolbar and
as the empty state's lead action, presenting the import sheet. The
measurable clause is that the sheet and both hosting roots render (the
retired criteria's stance); button chrome, sheet presentation, and the
empty-state copy are visual-verify.

## [PIPEBOARD-42] Create CV on a snapshot-less application presents tailoring against its stored job description

The pause-at-the-application step (decisions/0008): the created draft is
selected on the board and its detail offers a prominent "Create CV" — shown
only while `cvSnapshot` is nil (the write-once invariant, [CVEXPORT-1]) and
the trimmed job description is non-empty ([PIPEBOARD-33]'s remove can empty
it). The offer decision is a pure helper so the rule is testable without
views; pressing it presents the tailor for this application ([TAILOR-23])
and the export attaches the CV to it ([CVEXPORT-22]). Button prominence and
sheet presentation are visual-verify.

## [PIPEBOARD-43] The application detail shows the Application's Match score with its matched Tags and vocabulary gaps

The Match section's summary, read straight from the persisted Match
([TAILOR-37]) — score derived live ([TAILOR-41]), matched Tag names,
vocabulary gap strings. Display only: nothing here writes. Because the
display derives from the persisted Match, a re-scan's replacement
([TAILOR-36]) and a confirmed review's gap-moves ([TAILOR-49]) show without
any refresh step. Section chrome, ordering and the scanned-at caption are
visual-verify.

## [PIPEBOARD-44] Scan JD on the application detail presents the Match review for its stored job description

The on-demand door (decisions/0009): pressing Scan JD runs the JD scan
against the stored job description — a repeat scan replaces the Match,
[TAILOR-36] — and on success presents the same Match review the tailor flow
uses ([TAILOR-46]–[TAILOR-51], unchanged and single-owned). While the scan
runs the action shows progress and cannot be pressed again. The review's
confirm copy is neutral ("Done"), never "Continue to tailoring" — this door
ends at the detail. Sheet presentation and progress chrome are
visual-verify.

## [PIPEBOARD-45] The Match section appears only while the application's trimmed job description is non-empty

The gate is the JD alone — any status, snapshot or not (deliberately unlike
Create CV's snapshot-less gate, [PIPEBOARD-42]): the Match stays useful
after export, and later preview stats read it. Removing the job description
([PIPEBOARD-33]) hides the section even when a Match persists — the Match
describes a JD no longer present; it returns when a JD does. The offer
decision is a pure helper so the rule is testable without views (the
[PIPEBOARD-42] stance).

## [PIPEBOARD-46] A Match-less application's Match section shows the scan prompt

The empty state: no score, no Tag lists, no gap rows — a line inviting the
first scan, with Scan JD as its action ([PIPEBOARD-44]). A pre-Match store
opens with every Match absent ([TAILOR-42]), so this is also every existing
application's first view of the section. Prompt copy is visual-verify.

## [PIPEBOARD-47] Confirming the on-demand Match review sends no tailor request

Decisions/0009's delta from the tailor flow: confirm applies the review
outcome — accepted suggestions land in the pool, resolved gaps move
([TAILOR-48], [TAILOR-49]) — and returns to the detail, whose summary
already reflects the change ([PIPEBOARD-43]). No tailor run follows,
asserted via the fixture service's recorded requests (the [TAILOR-44]
stance). Cancel likewise returns to the detail keeping the freshly scanned
Match ([TAILOR-50]).

## [PIPEBOARD-48] A failed on-demand scan shows the failure reason with a retry action

Every scan failure surfaces beside the Match section with its reason — no
API key, request failure, truncation, a response still invalid after the
single repair ([TAILOR-31], with [TAILOR-32] keeping the persisted Match
unchanged) — and retry re-runs the scan. An empty job description cannot
fail here: the section is not offered without one ([PIPEBOARD-45]). Message
chrome is visual-verify.
