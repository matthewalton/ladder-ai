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
The scan is headless this amendment — a store seam, no UI door.

The tailor flow itself stays transient (decisions/0001): the tailor result
and reviewed outcome live in memory only. The Match is the slice's one
persisted artefact (decisions/0011); everything else that persists arrives
via the cv-export slice. Without a stored API key a run refuses and points
to Settings (decisions/0002); the model is pinned to the latest Sonnet
(decisions/0003); validation failures get exactly one repair request
(decisions/0004).

Out of scope: PDF render, `Application`/`cvSnapshot` persistence, the fit
report view (all cv-export), removing an achievement from the selection during
review, model picker, streaming, anything under the phase gate — and, until
the Match review arrives (ticket #162 slice 3), everything root ADR 0005
gates behind it: the review UI with suggestion checkboxes, wiring the scan as
the tailor run's automatic first step, selection scoring and the ranked
payload, the overlap view, and the FitMetrics content budget.

## [TAILOR-1] Running a tailor for a job description produces a tailor result for review

The tracer criterion: job details (company, role title, job description —
since decisions/0008 arriving from the Application, [TAILOR-23]) → payload
built from the Profile → intelligence service → validated tailor result held
for review. It proves the details input, the payload and prompt assembly,
the service seam, decode-based validation, and the tailor flow's state
machine end to end.

Exercised with `FixtureIntelligenceService` returning a canned tailor result
from `LadderTests/Fixtures/`. The result is transient — a tailor run
persists nothing (decisions/0001); the Match is written by the JD scan
alone (decisions/0011).

## [TAILOR-2] A tailor run with an empty job description is refused

Refused at start, before any service call. Whitespace-only counts as empty.
Company and role title are free-text labels carried into the payload; only the
job description is required for a run.

## [TAILOR-23] A tailor presented for an application starts from its stored job details

decisions/0008: the run's `JobDetails` derive from the Application — company,
role title and job description verbatim — and the tailor run starts on
presentation with no input step; the view offers no editing of the details
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
scan alone (decisions/0011), and no scan runs here.

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
store's view is never stale ([PROFILE-34]/[PROFILE-35] precedent) — and
confirmation arrives with the Match review, out of scope this amendment.

## [TAILOR-30] A JD scan returns its Tag suggestions without persisting them

The pool-level kinds — mint and alias (root ADR 0005) — arrive in the scan
result, held in memory for the Match review to consume (decisions/0013); the
canned fixture carries both. Attach is a point-door kind: it grounds in a
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
resurrected as a vocabulary gap — gaps change only when a scan runs
([TAILOR-36]); until then the Match simply matches less.

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
