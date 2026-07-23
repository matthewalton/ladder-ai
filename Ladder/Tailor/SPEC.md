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
fields (text, impact metric, tech, Tags, strength notes) and never invents
facts; education and interests travel in the payload as context only. This
slice owns the tailor presentation, the tailor run and its validation, the
review, `Prompts/tailor.md`, and the app's live-LLM firsts: the Settings
scene with Keychain API key entry, the live Anthropic `IntelligenceService`
implementation, and the retry-with-repair loop deferred here by
[CVIMPORT-10]. It also owns the CV template's service passes: the per-CV
skill grouping in the tailor result (decisions/0009) and the condense and
trim passes cv-export's fit loop calls (decisions/0010) — cv-export renders
what these return, never rewords anything itself.

The whole flow is transient (decisions/0001): the tailor result and reviewed
outcome live in memory only; the `Application` model and any persistence arrive
with the cv-export slice. Without a stored API key the run refuses and points
to Settings (decisions/0002); the model is pinned to the latest Sonnet
(decisions/0003); validation failures get exactly one repair request
(decisions/0004).

Out of scope: PDF render, `Application`/`cvSnapshot` persistence, the fit
report view (all cv-export), removing an achievement from the selection during
review, model picker, streaming, anything under the phase gate.

## [TAILOR-1] Running a tailor for a job description produces a tailor result for review

The tracer criterion: job details (company, role title, job description —
since decisions/0008 arriving from the Application, [TAILOR-23]) → payload
built from the Profile → intelligence service → validated tailor result held
for review. It proves the details input, the payload and prompt assembly,
the service seam, decode-based validation, and the tailor flow's state
machine end to end.

Exercised with `FixtureIntelligenceService` returning a canned tailor result
from `LadderTests/Fixtures/`. The result is transient — nothing is persisted
at any point in this slice (decisions/0001).

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
achievements, their texts, and all counts are byte-identical, and nothing new
is persisted (decisions/0001).

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
dates, actual roles, tech, and metrics; the no-invention stance of bullets
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
