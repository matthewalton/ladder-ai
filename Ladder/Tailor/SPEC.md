---
key: TAILOR
---

# Tailor

Paste a job description, have the intelligence service select the best-fit
Achievements from the Profile, propose a per-application rephrasing for each,
flag gaps, and state its rationale — then review each rephrasing side by side
before anything is used. This slice owns the tailor sheet, the tailor run and
its validation, the review, `Prompts/tailor.md`, and the app's live-LLM firsts:
the Settings scene with Keychain API key entry, the live Anthropic
`IntelligenceService` implementation, and the retry-with-repair loop deferred
here by [CVIMPORT-10].

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

## [TAILOR-3] Starting a tailor run when the Profile has no achievements is refused

Tailoring selects from Achievements and never free-writes career history
(root CONTEXT.md) — with nothing to select from, a run is meaningless. Refused
before any service call; the refusal points at adding achievements or
importing a CV.

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

## [TAILOR-11] The review shows each rephrasing beside its achievement's canonical text

The side-by-side: for every selected achievement, the canonical
`Achievement.text` and the proposed rephrasing appear together, so the user
judges the rewording against the canon it came from.

## [TAILOR-12] Every rephrasing enters review as accepted

Nothing is pre-rejected on the user's behalf — the same stance as
[CVIMPORT-4]. The user rejects the rewordings they don't want.

## [TAILOR-13] The reviewed outcome uses the rephrasing for an accepted achievement

The reviewed outcome is what cv-export will consume: per selected achievement,
one final text. Accepted → the proposed rephrasing.

## [TAILOR-14] The reviewed outcome uses the canonical text for a rejected rephrasing

Rejecting a rephrasing keeps the achievement in the selection with its
canonical `Achievement.text` — the selection stood; only the rewording was
declined. Removing an achievement from the selection entirely is out of scope
this slice.

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

## [TAILOR-18] A tailor result wrapped in a markdown code fence produces a review

Live models mirror the fenced schema example in `Prompts/tailor.md` and wrap
their JSON in a ```json fence despite the "only JSON" instruction — cv-import
hit this live first ([CVIMPORT-18]). The fence is presentation, not content:
it is stripped before validation (the shared `FencedJSON` helper), so a
fenced-but-valid result reaches review without consuming the single repair
request (decisions/0004) on a formatting quirk. The prompt also forbids
fences explicitly, but tolerance must not depend on the model obeying.
