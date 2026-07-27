---
key: TAILOR
---

# Tailor

Tailor an application's stored job description: the intelligence service
selects the best-fit content from the Profile — role Achievements point by
point, Projects whole (decisions/0007) — and expands each brief talking
point into one polished CV bullet, generates a CV summary tailored to the
job description (decisions/0006), flags gaps, and states its rationale —
then each expanded bullet is reviewed side by side before anything is used.
The job details — company, role title, job description — arrive from the
Application the tailor is presented for (decisions/0008); the tailor
collects nothing by hand. Expansion is grounded strictly in the point's own
fields (text, impact metric, Tags, strength notes — `tech` merged into Tags,
Profile decisions/0011) and never invents facts; education and interests
travel in the payload as context only. This
slice owns the tailor presentation, the tailor run and its validation, the
review, `Prompts/tailor.md`, and the app's live-LLM firsts: the Settings
scene with Keychain API key entry, the live Anthropic `IntelligenceService`
implementation, and the retry-with-repair loop deferred here by
[CVIMPORT-10]. It also owns the CV template's service passes: the per-CV
skill grouping in the tailor result (decisions/0009) and the condense and
trim passes cv-export's fit loop calls (decisions/0010) — cv-export renders
what these return, never rewords anything itself.

Since ticket #162 slice 2 the slice also owns tailoring's first step, the JD
scan (root `CONTEXT.md`): the intelligence service reads an Application's
stored job description against the Profile's Tag vocabulary — primary names
and Aliases — and the validated scan result is persisted as the Application's
Match: matched Tags as live `SkillTag` references, vocabulary gaps as
strings, refreshed by every scan (decisions/0011). The scan's Tag
suggestions stay transient (decisions/0013), and the deterministic Match
score derives from the Match, never stored (decisions/0012; root ADR 0005).

Since ticket #162 slice 3 the scan is tailoring's automatic first step:
presenting the tailor scans, the Match review confirms the vocabulary —
suggestions as checkboxes, the score recomputing live and offline — and only
then does selection run, grounded in the confirmed Match; a failed scan fails
the flow, never a raw-JD fallback (root ADR 0005; decisions/0014). A
suggestion may name the vocabulary gap it resolves (`resolves`, jd-scan.md
v2), and confirming one moves that gap into the matched Tags
(decisions/0015). The tailor payload arrives annotated and ordered by each
point's matched-Tag overlap, carries the content budget FitMetrics history
supports (decisions/0016), and the tailor review gains the overlap view.

Since ticket #195 the tailor result also carries per-point relevance stats:
four LLM-judged criteria — tech/tooling, topic/domain,
responsibility/seniority, impact/outcome — scored per selected point in the
same tailor request, with an overall relevance computed in Swift as their
unweighted mean (decisions/0017). The review shows them beside the
deterministic overlap view — the judged and deterministic signals sit side
by side, never merged — and the stats are transient with the result
(decisions/0001) and never a factor in the Match score (root ADR 0005).

The tailor flow itself stays transient (decisions/0001): the tailor result
and reviewed outcome live in memory only. The Match is the slice's one
persisted artefact (decisions/0011); everything else that persists arrives
via the cv-export slice. Without a stored API key a run refuses and points
to Settings (decisions/0002); the model is pinned to the latest Sonnet
(decisions/0003); validation failures get exactly one repair request
(decisions/0004).

Out of scope: PDF render, `Application`/`cvSnapshot` persistence, the fit
report view (all cv-export), removing an achievement from the selection during
review, model picker, streaming, anything under the phase gate — and
persisting relevance stats, deferred to the CV-composition record (Baton
#164; decisions/0017). The on-demand scan door on the Application detail
shipped in PipelineBoard ([PIPEBOARD-44]).

## [TAILOR-1] Running a tailor for a job description produces a tailor result for review

The tracer criterion: job details (company, role title, job description —
since decisions/0008 arriving from the Application, [TAILOR-23]) → payload
built from the Profile → intelligence service → validated tailor result held
for review. It proves the details input, the payload and prompt assembly,
the service seam, decode-based validation, and the tailor flow's state
machine end to end.

Exercised with `FixtureIntelligenceService` returning a canned tailor result
from `LadderTests/Fixtures/`. The result is transient — a tailor run
persists nothing (decisions/0001); the Match is written by the JD scan and
the Match review's confirmation alone (decisions/0011, 0015).

## [TAILOR-2] A tailor run with an empty job description is refused

Refused at start, before any service call. Whitespace-only counts as empty.
Company and role title are free-text labels carried into the payload; only the
job description is required for a run.

## [TAILOR-23] A tailor presented for an application starts from its stored job details

decisions/0008: the run's `JobDetails` derive from the Application — company,
role title and job description verbatim — and the flow starts on
presentation with no input step (since slice 3 the JD scan runs first,
[TAILOR-43], and the tailor run follows the confirmed Match review,
[TAILOR-45]); the view offers no editing of the details
(the JD is corrected on the application detail, [PIPEBOARD-21..28], and
re-tailored from there). The measurable clause is the derivation and the
recorded fixture payload carrying the stored values verbatim; the auto-run
presentation and the absence of input chrome are visual-verify. Replaces the
tailor sheet's input form ([TAILOR-1]'s former "sheet inputs" clause —
retired with the standalone entry, [PIPEBOARD-34] → [PIPEBOARD-41]).

## [TAILOR-3] Starting a tailor run when the Profile has neither achievements nor projects is refused

Tailoring selects from the Profile and never free-writes career history (root
CONTEXT.md) — with nothing to select from, a run is meaningless. A Profile
whose only selectable content is a project is enough: projects are selected
whole (decisions/0007) exactly as role Achievements are selected point by
point. Refused before any service call; the refusal points at adding
achievements or importing a CV.

## [TAILOR-4] Starting a tailor run with no API key stored is refused

Checked at run start, before any service call. The refusal directs the user to
Settings to enter a key. Production never falls back to fixture data
(decisions/0002); `FixtureIntelligenceService` stays a test and preview
concern.

## [TAILOR-5] The tailor request contains the versioned tailor prompt

`Prompts/tailor.md` is born in this slice: the canonical, versioned tailor
prompt, loaded at runtime — never an inline string (and never a
`TailorPrompts/` folder). The fixture service records the request it receives;
the recorded prompt equals the file's content, and the recorded payload
carries the Profile's achievements and the pasted job description.

## [TAILOR-6] The tailor result lists each gap the service flagged

Gaps come from the service — "the JD wants Kubernetes; nothing in the profile
mentions it" — and the slice surfaces them verbatim, never re-derives them.
Exercised with a fixture result containing gaps; each appears in the result
shown alongside the review.

## [TAILOR-7] The tailor result carries the service's selection rationale

The service's stated reasoning for its selection, surfaced verbatim for
transparency. cv-export later persists it as `cvSelectionRationale`; this
slice only holds and shows it.

## [TAILOR-8] A tailor result selecting an achievement not on the Profile fails validation

Selection references existing content by identifier — `a…` for Achievements,
`p…` for Projects; an identifier matching nothing on the Profile means the
service invented or garbled history.
Referential failure is handled exactly like a schema mismatch: it feeds the
repair path ([TAILOR-9], [TAILOR-10]).

## [TAILOR-9] A response failing validation triggers exactly one repair request

The retry-with-repair loop arrives here (deferred by [CVIMPORT-10]). The
repair request carries the original request content, the invalid response, and
a description of the validation failure for the service to fix. A valid repair
response produces the tailor result as normal. Exactly one — asserted via the
fixture service's recorded requests: an invalid-then-valid sequence records
two requests, never three (decisions/0004).

## [TAILOR-10] A repair response failing validation fails the run

The second failure ends the run in the failed state with
`TailorError.resultInvalid`; no review is offered, no further request is sent,
and the Profile is unchanged (decisions/0004).

## [TAILOR-11] The review shows each expanded bullet beside its achievement's canonical text

The side-by-side: for every selected point, the canonical brief
`Achievement.text` and the expanded bullet appear together, so the user judges
the expansion against the talking point it grew from. The review groups items
under the role the point belongs to; selected projects list as whole units
beneath ([TAILOR-22]) — nothing per-project to accept or reject.

## [TAILOR-12] Every expanded bullet enters review as accepted

Nothing is pre-rejected on the user's behalf — the same stance as
[CVIMPORT-4]. The user rejects the bullets they don't want.

## [TAILOR-13] The reviewed outcome uses the expanded bullet for an accepted achievement

The reviewed outcome is what cv-export will consume: per selected point, one
final text. Accepted → the expanded bullet.

## [TAILOR-14] The reviewed outcome uses the canonical text for a rejected bullet

Rejecting a bullet keeps the point in the selection with its canonical brief
`Achievement.text` — the selection stood; only the expansion was declined, and
the user's own terse wording goes on the CV (a documented consequence, not a
surprise). Removing a point from the selection entirely is out of scope this
slice.

## [TAILOR-15] A completed tailor run and review leave the persisted Profile unchanged

Rephrasings never mutate `Achievement.text` — the canon is user-owned (root
CONTEXT.md). Exercised end to end: run, review, accept everything; the store's
achievements, their texts, and all counts are byte-identical, and the run and
review persist nothing (decisions/0001) — the Match is written by the JD
scan and the Match review's confirmation alone (decisions/0011, 0015), and
neither runs here. The Match review's pool writes ([TAILOR-48]) are its own
door, exercised there — never a side effect of the run or the bullet review.

## [TAILOR-16] A saved API key round-trips through the Keychain store

Save then read returns the key; delete removes it. Stored as a Keychain
generic-password item — never UserDefaults, never on disk, never logged
(CLAUDE.md). The store sits behind a protocol so other tests fake it; this
criterion exercises the real Keychain implementation.

## [TAILOR-17] A live service request carries the stored API key

The live `AnthropicIntelligenceService`, tested at the request-building seam —
no network in tests. The built request targets the Anthropic Messages API
(`https://api.anthropic.com/v1/messages`), carries the key in the `x-api-key`
header with the required `anthropic-version` header, and pins the model to the
latest Sonnet (decisions/0003; exact model ID verified against current API
docs at implement time). The prompt travels as the system prompt, the payload
as the user message.

## [TAILOR-19] The tailor payload carries projects, education and interests

Beyond roles: each project serializes as one unit — stable `p…` id, name,
summary, description, and Tags under the `tags` key (decisions/0007) —
education and interests serialize as context the model may lean on but never
select from. Ids stay stable within one payload; validation resolves
selections against the union of `a…` and `p…` ids.

## [TAILOR-22] A selection may include a whole project

Replaces [TAILOR-20]'s per-point framing (decisions/0007): selecting a `p…`
id puts that project — description and Tags as they stand on the Profile,
never expanded or reworded — into the reviewed outcome and onto the tailored
CV (cv-export renders only selected projects, [CVEXPORT-21]). An omitted
project simply stays off the CV.

## [TAILOR-21] The reviewed outcome carries the result's generated CV summary verbatim

The CV summary is generated per tailor run, tailored to the job description,
and never stored on the Profile (decisions/0006 — settled with the human: a
summary should read against the JD, so it has no canonical stored form). It is
grounded strictly in payload facts — years of experience derived from role
dates, actual roles, Tags, and metrics; the no-invention stance of bullets
applies. Required by the result schema, so a result without one feeds the
repair path ([TAILOR-9]); the review shows it beside the rationale, and it
travels into the reviewed outcome verbatim for cv-export to render
([CVEXPORT-20]).

## [TAILOR-18] A tailor result wrapped in a markdown code fence produces a review

Live models mirror the fenced schema example in `Prompts/tailor.md` and wrap
their JSON in a ```json fence despite the "only JSON" instruction — cv-import
hit this live first ([CVIMPORT-18]). The fence is presentation, not content:
it is stripped before validation (the shared `FencedJSON` helper), so a
fenced-but-valid result reaches review without consuming the single repair
request (decisions/0004) on a formatting quirk. The prompt also forbids
fences explicitly, but tolerance must not depend on the model obeying.

## [TAILOR-24] The tailor result groups the selected skills into named categories

The skill grouping (decisions/0009): the result schema — and
`Prompts/tailor.md`, version-bumped — gains categories, each a service-chosen
name over skills drawn from the selection's Tag union (the vocabulary bound
CVExport decisions/0004 established; the union is now grouped, never dumped
flat). A grouping naming a skill outside that union fails validation and
feeds the repair path ([TAILOR-9]). The grouping is per-CV and transient —
no `SkillTag` model change — and travels through the reviewed outcome
verbatim for cv-export's skills table ([CVEXPORT-23]).

## [TAILOR-25] A condense pass returns the same selection with shortened bullet texts

The fit loop's second rung (decisions/0010; [CVEXPORT-26]): the request
carries the reviewed outcome's current texts, and the response keeps the
selection identical — validation rejects any added or removed `a…`/`p…` id,
feeding the single repair ([TAILOR-9] stance). Shortening is grounded in the
existing bullet alone — no new facts — and achievement titles travel
untouched (root `CONTEXT.md`: tailoring never writes the title). The
versioned prompt is `Prompts/condense.md`; exercised with
`FixtureIntelligenceService` like every service call.

## [TAILOR-26] A trim pass returns a strict subset of the selection

The fit loop's terminal rung (decisions/0010; [CVEXPORT-27]): the service
drops the items weakest for this job description, and validation accepts
only a non-empty strict subset of the sent selection — anything else feeds
the single repair, and a failed repair fails the export run with the reason
surfaced (no silent fallback). The removed items are the fit report's trim
list ([CVEXPORT-28]). The versioned prompt is `Prompts/trim.md`.

## [TAILOR-27] A JD scan stores a Match on the Application

The amendment's tracer: the scan seam (`JDScanStore`) takes an Application,
builds the payload from its stored job description and the Profile's Tag
vocabulary, sends it through the intelligence service, validates the scan
result, and persists the Match — matched Tags resolved case-insensitively
through primary names and Aliases to the pool's live `SkillTag` instances
(never copies; two asks resolving to the same Tag land one reference),
vocabulary gaps stored verbatim as strings, `scannedAt` stamped. A fresh
context sees the Match, so it saved.

The `Match` model is one-to-one from `Application` with cascade delete (the
`JourneyNarrative` shape); the model file lives in this slice's `src/`, and
`Application` gains the relationship amended in place in
`Ladder/CVExport/src/` (the PipelineBoard decisions/0001 precedent —
[CVEXPORT-11] stays green). Exercised with `FixtureIntelligenceService`
returning the canned scan result; the fixture's matched names deliberately
arrive in non-primary casing and via an Alias to prove resolution.

## [TAILOR-28] The scan request carries the versioned jd-scan prompt and the pool vocabulary

`Prompts/jd-scan.md` is born in this amendment: canonical, versioned, loaded
at runtime — never an inline string (the [TAILOR-5] stance). The fixture
service records the request it receives: the recorded prompt equals the
file's content, and the recorded payload carries the Application's job
description verbatim plus every pool Tag's primary name with its Aliases
([PROFILE-31]'s vocabulary shape) — the model matches or aliases before it
mints, and a flagged vocabulary gap is then a genuine one.

## [TAILOR-29] A scan result matching a name absent from the pool fails validation

Matched names resolve against the pool case-insensitively across primary
names and Aliases; a "matched" name resolving to nothing means the model
invented vocabulary, and the failure feeds the repair path exactly like a
schema mismatch ([TAILOR-9] stance). Suggestions are not validated against
the pool here: their pool consistency is enforced at confirmation, where the
store's view is never stale ([PROFILE-34]/[PROFILE-35] precedent) — the
Match review's confirmation door, [TAILOR-48]. A suggestion's `resolves`
reference is the exception: it points into the scan result itself, so it is
checked at validation ([TAILOR-51]).

## [TAILOR-30] A JD scan returns its Tag suggestions without persisting them

The pool-level kinds — mint and alias (root ADR 0005) — arrive in the scan
result, held in memory for the Match review to consume ([TAILOR-46];
decisions/0013); the canned fixture carries both. Attach is a point-door kind: it grounds in a
point's evidence and moves per-point stats, never the vocabulary-level Match
score, so the scan — which reads only the JD and the vocabulary — never
proposes it; the on-demand and import doors own it (decisions/0013). After
the scan, a store reopen shows the Match holding only matched Tags, gaps,
and `scannedAt` — no suggestion data anywhere in the store, and the pool
unchanged: the LLM proposes, only the user writes.

## [TAILOR-31] An invalid scan response gets exactly one repair request

The decisions/0004 loop: a response failing the scan schema — or
[TAILOR-29]'s referential check — triggers one repair request carrying the
original request content, the invalid response, and the failure reason. An
invalid-then-valid sequence records two requests, never three. A
fenced-but-valid response is stripped by the shared `FencedJSON` helper and
consumes no repair ([TAILOR-18]'s tolerance).

## [TAILOR-32] A scan whose repair response fails validation leaves the Application's Match unchanged

The second failure ends the scan in a failed state with the reason surfaced,
and the store is untouched: an existing Match keeps its matched Tags, gaps,
and `scannedAt` exactly; an Application that never had one still has none.
No partial Match is ever written.

## [TAILOR-33] A JD scan on an empty job description is refused

Refused at start, before any service call — whitespace-only counts as empty
(the [TAILOR-2] stance). The Application's Match, if any, is unchanged.

## [TAILOR-34] A JD scan with no API key stored is refused

Checked before any service call; the refusal points to Settings, and
production never falls back to fixture data (decisions/0002) —
`FixtureIntelligenceService` stays a test and preview concern.

## [TAILOR-35] The scan run creates its live service with the stored API key

The key store plus `makeIntelligence` factory shape ([PROFILE-38];
decisions/0002 and 0003 lineage): exercised without network via a fake key
store holding a known key and a factory recording the key it was handed. The
default factory is the shared `AnthropicIntelligenceService` (pinned model).

## [TAILOR-36] A second JD scan replaces the Application's Match

The Match tracks the pool, never freezes (root `CONTEXT.md`: Match): each
scan resolves against the pool as it now stands, the previous matched
references and gaps are gone, and `scannedAt` moves. An Application has at
most one Match — a `Match` fetch after the second scan counts one for it,
no orphans. The immutable record of what was sent remains the CV snapshot.

## [TAILOR-37] A fully-populated Match round-trips through a store reopen

The model-change persistence test CLAUDE.md requires ([PIPEBOARD-3]'s
pattern): matched Tags, vocabulary gaps, and `scannedAt` all populated,
value-equal after closing and reopening the store on the same on-disk
container. The schema grows a V3 `VersionedSchema` step in
`LadderSchemaVersions.swift` with a lightweight V2→V3 stage — new model, new
optional relationship, nothing folded — and `Match.self` registers wherever
the container's schema is built.

## [TAILOR-38] Deleting an Application removes its Match

The cascade delete rule, proven by a fetch ([PIPEBOARD-11]'s pattern): after
deleting an Application with a Match, a `Match` fetch returns no orphans —
and the matched `SkillTag`s themselves survive; only the references go.

## [TAILOR-39] A pool Tag rename propagates into every Match referencing it

Matched Tags are the shared `SkillTag` instances, so a recase through the
manage sheet ([PROFILE-29]; renames are recase-only, [PROFILE-30]) shows in
the Match without touching it — the live-reference storage root ADR 0005
leans on.

## [TAILOR-40] Deleting a pool Tag removes it from every Match's matched Tags

The relationship empties, never dangles. The ask the Tag covered is not
resurrected as a vocabulary gap — gaps change only when a scan runs or a
confirmed resolving suggestion moves one ([TAILOR-36], [TAILOR-49]); until
then the Match simply matches less.

## [TAILOR-41] A Match derives its score from its matched and gap counts alone

The deterministic Match score (root ADR 0005; decisions/0012): a pure
helper computes matched ÷ (matched + gaps) as a whole percentage, rounded
half-up — 12 matched with 6 gaps → 67 (12 ÷ 18 = 66.7); 5 matched with 0
gaps → 100; 0 matched with 5 gaps → 0. A Match with no asks at all — zero
matched, zero gaps — has no score (nil), never a divide-by-zero or a fake
100. The score is derived on read and never stored (decisions/0012), so
slice 3's review can recompute it live and offline as suggestions toggle.

## [TAILOR-42] A pre-Match store opens with every Application's Match absent

Migration safety for the V2→V3 step: the committed fixture stores
(`LadderTests/Fixtures/Phase1Store/`, `PreTechMigrationStore/` — never
regenerate either) travel the full migration chain and open with every
Application carrying no Match; their existing rows stay defended by
[PIPEBOARD-2] and the Profile migration criteria, which keep running under
the new schema.

## [TAILOR-43] A tailor presentation runs the JD scan before any tailor request

The scan-first wiring (root ADR 0005: the Match review precedes selection;
decisions/0014). Presenting the tailor for an Application starts the JD scan
automatically — the fixture service's recorded requests open with the
jd-scan prompt, and no tailor prompt is among them until the Match review
confirms ([TAILOR-45]). Every presentation re-scans: the Match tracks the
pool ([TAILOR-36]), so a persisted Match from an earlier run never
short-circuits the scan. The existing refusals keep their semantics, all
before any service call: empty job description ([TAILOR-2], [TAILOR-33]),
no API key ([TAILOR-4], [TAILOR-34]), nothing selectable on the Profile
([TAILOR-3]).

## [TAILOR-44] A failed JD scan ends the tailor flow with no tailor request sent

decisions/0014: a scan transport failure, truncation, or an invalid repair
response ([TAILOR-32]) fails the whole flow — the reason surfaced, retry
offered (retry re-runs from the scan) — and the recorded requests carry no
tailor prompt. Selection never runs against a raw JD, and never against the
stale persisted Match either: there is no fallback path of any kind.

## [TAILOR-45] The tailor run starts only after the Match review is confirmed

After a scan lands, the flow holds in the Match review ([TAILOR-46]);
however long it sits there, the fixture service's recorded requests grow no
tailor prompt. Confirming ([TAILOR-48]) starts the tailor run against the
Match as confirmation left it ([TAILOR-49], [TAILOR-52]). Cancelling
instead ends the flow with no tailor request at all ([TAILOR-50]).

## [TAILOR-46] The Match review presents the Match score with its matched Tags, vocabulary gaps and Tag suggestions

The second review step tailoring gained (root ADR 0005; root `CONTEXT.md`:
Match). The score is [TAILOR-41]'s derivation — a no-asks Match shows no
score, never a fake 100; matched Tags show by primary name; vocabulary gaps
verbatim; and each of the scan's transient mint/alias suggestions
([TAILOR-30]) appears as a checkbox with its rationale. Suggestions enter
the review **unchecked**: unlike [TAILOR-12]'s bullets — rewordings of the
user's own canon — a suggestion writes a vocabulary claim into the pool, and
claiming a skill is opt-in, never opt-out (root ADR 0005: propose, never
stuff). Which controls render where is visual-verify; the presented state is
the testable surface.

## [TAILOR-47] Toggling a Tag suggestion recomputes the review's score without any service request

The live, offline recompute root ADR 0005 promises, from [TAILOR-41]'s
derivation: while checked, a resolving suggestion (decisions/0015) counts
its gap as matched — 12 matched with 6 gaps shows 67; checking a suggestion
that resolves one gap shows 13 ÷ 18 = 72; unchecking returns to 67. A
suggestion with no `resolves` moves the score by nothing. The fixture
service records zero requests across any number of toggles.

## [TAILOR-48] Confirming the Match review writes each accepted suggestion to the Tag pool

The Match review confirmation door (root ADR 0005; the
[PROFILE-34]/[PROFILE-35] semantics, stale-view safe): an accepted mint
resolves alias-aware first and creates the Tag in its curated casing only
when nothing resolves — never a duplicate; an accepted alias lands
lowercase on its resolved Tag, and a colliding alias refuses exactly as a
manual one ([PROFILE-27] stance) without derailing the other accepted
suggestions — each applies independently ([PROFILE-36]'s per-proposal
stance). Unchecked suggestions land nothing and die with the flow
(decisions/0013).

## [TAILOR-49] A confirmed resolving suggestion moves its gap into the Match's matched Tags

decisions/0015: on confirmation the gap string leaves `vocabularyGaps` and
the resolved Tag — the minted Tag, or the alias's Tag — joins the matched
Tags; a Tag already matched lands no second reference ([TAILOR-27]'s
dedup), the gap just goes. A store reopen shows the moved state, and the
derived score ([TAILOR-41]) then equals what the review displayed at
confirm. This is the one door besides a scan that changes a Match
([TAILOR-40]'s amended stance); `scannedAt` does not move — no scan ran.

## [TAILOR-50] Cancelling the Match review leaves the pool and Match unchanged

No write of any kind: pool Tag count, every Tag's name and aliases, the
Match's matched Tags, vocabulary gaps, and `scannedAt` all exactly as the
scan left them — checked checkboxes included; only confirmation writes
([TAILOR-48]). The suggestions die with the flow (decisions/0013), and no
tailor request was sent ([TAILOR-45]).

## [TAILOR-51] A scan suggestion resolving an entry absent from the gaps fails validation

jd-scan.md bumps to v2 (decisions/0015): a suggestion may carry `resolves` —
the gap entry it dissolves, compared case-insensitively after trimming
against the scan's own `gaps` array. A `resolves` matching no gap entry is
the model pointing at nothing, and it feeds the single repair exactly like a
schema mismatch ([TAILOR-31]). `resolves` stays optional: a suggestion
without one is valid and simply never moves the score ([TAILOR-47]). The
canned fixture covers a resolving mint, a resolving alias, and a
non-resolving alias.

## [TAILOR-52] The tailor payload annotates each point with its overlap of the Match's matched Tags

The deterministic grounding (root ADR 0005): per achievement and project,
the intersection of its Tags with the confirmed Match's matched Tags — the
overlapping primary names plus their count, computed in Swift, never by the
model. A zero-overlap point carries an empty list and 0, so absence always
reads as "nothing overlaps", never "not computed". `Prompts/tailor.md`
version-bumps to explain the annotation; the model still selects
([TAILOR-1]) — the annotation grounds, never dictates.

## [TAILOR-53] The tailor payload orders achievements within each role and projects by descending overlap

Ranking is presentation of [TAILOR-52]'s counts: within each role,
achievements sort by descending overlap count; the projects list likewise.
Ties keep the Profile's own order (a stable sort), and the roles themselves
never reorder — chronology is the CV's spine. Recorded fixture payloads
prove the order.

## [TAILOR-54] The tailor review shows each selected point's covered matched Tags

The overlap view, per point: beside each selected achievement and project,
the matched Tags its own Tags cover, by primary name — the vocabulary-side
complement of the evidence gaps the result already lists ([TAILOR-6]). A
selected point covering nothing shows none. Derived in Swift from the
reviewed selection and the Match — never from the model's output.

## [TAILOR-55] The tailor review lists the matched Tags no selected point covers

The uncovered remainder of the overlap view: matched vocabulary the
selection leaves unevidenced, so the user can reconsider the selection
before export. When the selection covers every matched Tag there is nothing
to list. Recomputed from whatever the current selection is, not frozen at
result time.

## [TAILOR-56] The content budget takes each field's maximum across the exports that fit without service passes

decisions/0016: a pure helper reads every Application's `fitMetrics` (each
records its latest export, [CVEXPORT-30]) and keeps the qualifying records —
`finalPageCount` ≤ 2 with `condensePassRun` false and `trimPassCount` 0;
deterministic compaction and stretch are free, service passes disqualify.
The budget is the per-field maximum across qualifiers: records of 14 bullets
+ 3 projects and 10 bullets + 5 projects → a budget of 14 bullets, 5
projects (and the character maximum likewise) — the most volume known to
fit. Zero qualifying records → no budget ([TAILOR-58]), never an invented
default.

## [TAILOR-57] The tailor request carries the content budget derived from FitMetrics history

With qualifying history ([TAILOR-56]), the recorded fixture request carries
the budget as an advisory aim-for line — bullets, projects, characters — in
the version-bumped `Prompts/tailor.md`'s terms. Advisory only
(decisions/0016): the model aims the selection at the budget; the fit loop
stays the enforcement ([CVEXPORT-26..28] untouched, [TAILOR-25],
[TAILOR-26] unchanged).

## [TAILOR-58] A tailor run with no qualifying FitMetrics history sends no budget

No qualifying export history — a fresh store, or only exports that needed
condense or trim — means the payload carries no budget at all: no key, no
zeros, byte-shape identical to today's payload. First-run behaviour is
unchanged; the budget appears only once an export has proven what fits
(decisions/0016).

## [TAILOR-59] The tailor result carries four relevance scores for each selected point

The per-point stats root ADR 0005 deferred to tailor time (decisions/0017;
ticket #195). Four LLM-judged criteria per selected achievement and project
— tech/tooling, topic/domain, responsibility/seniority, impact/outcome —
each an integer 0 to 5, judged in the same tailor request, never a second
pass (decisions/0017). The result schema requires them per selected point,
and `Prompts/tailor.md` version-bumps to define the four criteria and the
scale. Exercised with the canned fixture result carrying stats for every
selected point; the recorded prompt still equals the file's content
([TAILOR-5]). Transient like the whole result (decisions/0001); persistence
is deliberately deferred (Baton #164; decisions/0017).

## [TAILOR-60] A tailor result missing a selected point's relevance scores fails validation

The invalid-stats class, every case feeding the single repair exactly like a
schema mismatch ([TAILOR-9]; decisions/0004): scores absent for a selected
point; any score outside 0 to 5 (a 6, a −1); stats keyed to an id outside
the selection — the model judged a point it did not select. An
invalid-then-valid sequence records two requests, never three. A
fenced-but-valid result is stripped by the shared `FencedJSON` helper first
and consumes no repair ([TAILOR-18]).

## [TAILOR-61] A selected point's overall relevance is the unweighted mean of its four relevance scores

Computed in Swift from the model's sub-scores, never returned by the model
(decisions/0017): scores 5, 4, 3, 2 → 3.5; 3, 3, 3, 2 → 2.75; 0, 0, 0, 0
→ 0. A mean of four integers lands on quarter precision, and the helper
preserves it exactly — display formatting is visual-verify. No weighting:
every criterion counts equally, so the aggregate can never disagree with
the visible sub-scores it derives from.

## [TAILOR-62] The tailor review shows each selected point's relevance scores beside its covered matched Tags

The LLM-judged complement of the overlap view ([TAILOR-54]): per selected
point, the four sub-scores and the overall relevance appear beside the
deterministic covered-Tags list — side by side, never merged into one
figure (root ADR 0005 keeps the deterministic and judged signals separate).
The presented state is the testable surface; which controls render where is
visual-verify ([TAILOR-46] stance). The review's grouping and ordering are
untouched: roles group ([TAILOR-11]), and relevance never reorders anything
— [TAILOR-53]'s deterministic payload sort likewise stands.

## [TAILOR-63] A tailor run carrying relevance stats leaves the Application's Match unchanged

Root ADR 0005's hard line, exercised: run the scan-first flow to a tailor
result whose fixture stats score every selected point, review, accept — the
Match's matched Tags, vocabulary gaps, and `scannedAt` are exactly as the
Match review's confirmation left them ([TAILOR-49]), and the derived score
([TAILOR-41]) is identical before and after the tailor run. Relevance stats
are per-point, vocabulary-blind, and die with the flow — nothing they carry
reaches the store ([TAILOR-15]'s guarantee extends over them).
