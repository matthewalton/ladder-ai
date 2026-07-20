---
key: PREP
---

# Prep pack

The second Phase 4 slice: before a Stage's call, generate a prep pack from
the Stage's kind, the Application's job description, the pasted prep
context, the prior debriefs in the Application, and the Profile — likely
questions, talking points mapped to Profile Achievements, a company brief
drawn from the JD and pasted context only (no scraping, ARCHITECTURE.md
§1), and mock tasks for technical-type stages. Generation is an explicit
user action in the Stage's settings, through the existing
`IntelligenceService` seam; `Prompts/prep.md` is born here.

A prep pack is forward-looking coaching, not evidence about what happened —
so unlike the debrief there are no grounding quotes (decisions/0002).
Validation is schema plus achievement-index range; talking points link to
the canon as real relationships resolved from payload indices
(decisions/0001). The whole pack exports as one markdown file — the
ARCHITECTURE.md §6 v1 ruling: exported, not interactive.

No numeric scores, no offer probabilities — the prep schema has no field
that could hold one (ARCHITECTURE.md §1).

Out of scope: journey synthesis (the next Phase 4 slice); scraping or any
network source beyond the Anthropic API; interactive in-app mock-task
answering (§6 ruling); any automatic generation — the API is called only
on the user's explicit action; anything under `Journey/` (phase gate).

## [PREP-1] A generated prep pack is still on the Stage after the app relaunches

The tracer: a Stage with a job description → generate → validated prep
pack persisted on `Stage.prepPack` → reopen the container → still there,
content intact. It proves the guards, payload and prompt assembly, the
service seam, validation, persistence, and the flow's state machine end to
end. Exercised with `FixtureIntelligenceService` returning a canned prep
result from `LadderTests/Fixtures/`.

## [PREP-2] A fully-populated PrepPack round-trips through a store reopen

Every field: `generatedAt`, likely questions, company brief, mock tasks
(title and brief), and each talking-point row with its text, mapped
achievements, and order. Field-for-field equality after reopening the
container — the house pattern ([PROFILE-5], [PIPEBOARD-3], [DEBRIEF-2]).

## [PREP-3] Deleting a Stage deletes its prep pack with it

Cascade: after the Stage is deleted and the context saved, a fetch finds
no orphaned `PrepPack` and no orphaned talking-point rows. The
Achievements linked from talking points survive untouched — the
relationship never cascades toward the Profile (decisions/0001, the
[DEBRIEF-3] stance).

## [PREP-4] A debrief-era Application survives the schema migration with its Stages and debriefs intact

Migration safety (Phase 4 exit): open a store written by the debrief-era
Phase 4 schema (no `PrepPack` model, no `Stage.prepPack` link) under the
new schema — every Application keeps its Stages, debriefs, attached notes,
and `cvSnapshot` byte-identical, and each Stage's `prepPack` is nil. The
[DEBRIEF-4] pattern, on a new `Phase4Store` fixture (written by the schema
at the debrief slice's landing; never regenerate it).

## [PREP-5] Generating a prep pack with no job description, no prep context and no prior debriefs is refused

Refused before any service call — only when all three inputs are absent or
whitespace-only is there nothing to ground prep in. A first-stage pack
with just a JD, and a later-stage pack riding on prior debriefs alone,
both generate. The refusal names the missing inputs — the [DEBRIEF-5]
honest-refusal stance.

## [PREP-6] Generating a prep pack with no API key stored is refused

Checked at run start, before any service call; the refusal directs the
user to Settings — the [TAILOR-4] / [DEBRIEF-6] stance. Production never
falls back to fixture data; `FixtureIntelligenceService` stays a test and
preview concern.

## [PREP-7] The prep request contains the versioned prep prompt

`Prompts/prep.md` is born in this slice: the canonical, versioned prep
prompt, loaded at runtime — never an inline string. The fixture service
records the request it receives; the recorded prompt equals the file's
content, and the recorded payload carries the Stage's kind and prep
context, the Application's company, role title, and job description, each
prior debrief (its stage kind, question entries, themes, signals, and
drills), and the Profile's achievements listed with their payload indices
(decisions/0001).

## [PREP-8] The prep payload's debriefs come only from Stages ordered before the prepped Stage

"Prior" is strict: walking the Application's stages by `sortIndex`, a
debrief on a later stage — or on the prepped stage itself — never enters
the payload (ROADMAP.md Phase 4: "the next stage's prep pack draws on
that debrief"). Stages without a debrief contribute nothing; order among
the included debriefs follows stage order.

## [PREP-9] The prep pack lists the service's likely questions in the service's order

Persisted verbatim as returned, never re-derived or reworded — the
[TAILOR-6] / [DEBRIEF-16] stance. On-screen arrangement goes to the
visual-verify list; this criterion pins the persisted content.

## [PREP-10] A talking point's mapped achievements resolve to Achievements on the Profile

The service references achievements by payload index; the store maps each
index back to the Achievement object it listed and links it — a real
relationship, so the link survives later rewording of the canon
(decisions/0001). A talking point with no mapped achievements is valid:
some points are about the company or the stage, not the career history.

## [PREP-11] An achievement reference matching no listed achievement fails validation

An index outside the payload's achievement list means the service invented
or garbled career history — the [TAILOR-8] / [DEBRIEF-12] stance.
Referential failure feeds the repair path ([PREP-15], [PREP-16]).

## [PREP-12] A technical-type Stage's prep pack carries the service's mock tasks

For a Stage whose kind is technical, system design, or take-home, the
request asks for mock tasks tuned to the JD's stack (ARCHITECTURE.md §4)
and the validated result's mock tasks — each a title and a brief — are
persisted verbatim in the service's order.

## [PREP-13] A result carrying mock tasks for a non-technical Stage fails validation

Mock tasks belong to technical-type stages only; a result that returns
them for any other kind is a schema violation and feeds the repair path
([PREP-15], [PREP-16]) — unwanted content is repaired away, never
silently dropped (the verbatim stance of [PREP-9]).

## [PREP-14] The prep pack carries the service's company brief verbatim

Persisted as returned, never re-derived. The prompt constrains the brief
to the job description and pasted prep context only — no scraping, no
outside knowledge presented as fact (decisions/0002). A result with no
company brief is valid when there is nothing to say.

## [PREP-15] A response failing validation triggers exactly one repair request

The [TAILOR-9] loop (Tailor decisions/0004): the repair request carries
the original request content, the invalid response, and a description of
the validation failure. A valid repair response produces the prep pack as
normal. Exactly one — an invalid-then-valid fixture sequence records two
requests, never three.

## [PREP-16] A repair response failing validation fails the run

The second failure ends the run in a failed state naming the reason;
nothing is written, and a prep pack already on the Stage stays exactly as
it was — replacement happens only on a valid result ([PREP-17]).

## [PREP-17] Generating a prep pack for a Stage that already has one replaces the existing pack

One prep pack per Stage (the ARCHITECTURE.md §3 to-one link). On a valid
result the old `PrepPack` and its talking-point rows are deleted from the
store, never orphaned — the [TRANSCRIPT-29] / [DEBRIEF-15] policy:
regenerating is the correction path, no confirmation step.

## [PREP-18] A prep result wrapped in a markdown code fence produces a prep pack

Live models mirror the fenced schema example in the prompt and wrap their
JSON in a ```json fence despite the "only JSON" instruction ([CVIMPORT-18],
[TAILOR-18], [DEBRIEF-17]). The shared `FencedJSON` helper strips it
before validation, so a fenced-but-valid result becomes a prep pack
without consuming the single repair request on a formatting quirk.

## [PREP-19] The exported markdown contains every section of the prep pack

The whole pack in one markdown file (the plan's export ruling, settling
ARCHITECTURE.md §6's v1 line): company brief, likely questions, talking
points — each with the text of its mapped Achievements — and mock tasks
when present. Sections with nothing to say are omitted rather than left
as empty headings. Export is offline string assembly through a
`FileDocument`; the save panel goes on the visual-verify list.
