---
key: TAILOR
---

# Tailor

Paste a job description, have the intelligence service select the best-fit
points from the Profile — role Achievements and project points alike — and
expand each brief talking point into one polished CV bullet, generate a CV
summary tailored to the job description (decisions/0006), flag gaps, and
state its rationale — then review each expanded bullet side by side before
anything is used. Expansion is grounded strictly in the point's own fields
(text, impact metric, tech, Tags, strength notes) and never invents facts;
education and interests travel in the payload as context only. This slice owns
the tailor sheet, the tailor run and its validation, the review,
`Prompts/tailor.md`, and the app's live-LLM firsts: the Settings scene with
Keychain API key entry, the live Anthropic `IntelligenceService`
implementation, and the retry-with-repair loop deferred here by [CVIMPORT-10].

The whole flow is transient (decisions/0001): the tailor result and reviewed
outcome live in memory only; the `Application` model and any persistence arrive
with the cv-export slice. Without a stored API key the run refuses and points
to Settings (decisions/0002); the model is pinned to the latest Sonnet
(decisions/0003); validation failures get exactly one repair request
(decisions/0004).

Out of scope: PDF render, `Application`/`cvSnapshot` persistence, the fit
report view (all cv-export), removing an achievement from the selection during
review, model picker, streaming, anything under the phase gate.

## [TAILOR-1] Running a tailor for a pasted job description produces a tailor result for review

The tracer criterion: tailor sheet (company, role title, job description) →
payload built from the Profile → intelligence service → validated tailor
result held for review. It proves the sheet inputs, the payload and prompt
assembly, the service seam, decode-based validation, and the tailor flow's
state machine end to end.

Exercised with `FixtureIntelligenceService` returning a canned tailor result
from `LadderTests/Fixtures/`. The result is transient — nothing is persisted
at any point in this slice (decisions/0001).

## [TAILOR-2] A tailor run with an empty job description is refused

Refused at start, before any service call. Whitespace-only counts as empty.
Company and role title are free-text labels carried into the payload; only the
job description is required for a run.

## [TAILOR-3] Starting a tailor run when the Profile has no points is refused

Tailoring selects from points and never free-writes career history (root
CONTEXT.md) — with nothing to select from, a run is meaningless. A Profile
whose only points live on a project is enough: project points are selectable
content exactly like role Achievements. Refused before any service call; the
refusal points at adding achievements or importing a CV.

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

Selection references existing Achievements by identifier; an identifier
matching nothing on the Profile means the service invented or garbled history.
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
under the role or project the point belongs to.

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

Beyond roles: projects serialize with their points (stable `p…` ids, the same
per-point fields as role achievements, with Tags under the `tags` key);
education and interests serialize as context the model may lean on but never
select from. Ids stay stable within one payload; validation resolves
selections against the union of `a…` and `p…` ids.

## [TAILOR-20] A selection may reference a project point

Selecting a `p…` id resolves to the project's point in the review exactly like
a role selection — and puts that project on the tailored CV (cv-export renders
only projects with at least one selected point).

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
