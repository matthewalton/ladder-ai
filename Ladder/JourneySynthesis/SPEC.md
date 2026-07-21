---
key: JOURNEY
---

# Journey synthesis

The third Phase 4 slice: when an Application reaches `.offer`, generate the
retrospective narrative over its full Stage chain — the story of the whole
pursuit, from application to offer — from the Application's details, each
Stage in chain order, and the debriefs those Stages carry. Generation is an
explicit user action on the Application detail, through the existing
`IntelligenceService` seam; `Prompts/journey.md` is born here.

The narrative is plain prose, persisted on the Application as a
`JourneyNarrative` model (decisions/0001) and shown as modest plain text.
It is the feedstock for the Phase 5 illustrated celebration view (Baton
#151 ruling: store + plain display now; `Journey/` stays gated). The
service contract is the house JSON-plus-one-repair loop carrying a single
`narrative` field (decisions/0002).

No numeric scores, no offer probabilities — a story, not a report
(ARCHITECTURE.md §1). The API is called only on the user's explicit
action (ROADMAP.md Phase 4 posture) — reaching `.offer` never generates
anything by itself.

Out of scope: the illustrated base-camp-to-summit celebration view and
anything under `Journey/` (Phase 5, gated); sharing or export; any
automatic generation.

## [JOURNEY-1] A generated journey narrative is still on the Application after the app relaunches

The tracer: an Application at `.offer` with a Stage chain → generate →
validated narrative persisted on `Application.journeyNarrative` → reopen
the container → still there, content intact. It proves the guards, payload
and prompt assembly, the service seam, validation, persistence, and the
flow's state machine end to end. Exercised with
`FixtureIntelligenceService` returning a canned journey result from
`LadderTests/Fixtures/`.

## [JOURNEY-2] A fully-populated JourneyNarrative round-trips through a store reopen

Every field: `text` and `generatedAt`. Field-for-field equality after
reopening the container — the house pattern ([PROFILE-5], [DEBRIEF-2],
[PREP-2]).

## [JOURNEY-3] Deleting an Application deletes its journey narrative with it

Cascade: after the Application is deleted and the context saved, a fetch
finds no orphaned `JourneyNarrative` — the [PIPEBOARD-11] stance extended
to the new link (decisions/0001).

## [JOURNEY-4] A prep-era Application survives the schema migration with its Stages, debriefs and prep packs intact

Migration safety (Phase 4 exit): open a store written by the prep-era
Phase 4 schema (no `JourneyNarrative` model, no
`Application.journeyNarrative` link) under the new schema — every
Application keeps its Stages, debriefs, prep packs, attached notes, and
`cvSnapshot` byte-identical, and each Application's `journeyNarrative` is
nil. The [DEBRIEF-4] / [PREP-4] pattern, on a new `Phase4PrepStore`
fixture (written by the schema at the prep-pack slice's landing; never
regenerate it).

## [JOURNEY-5] Generating a narrative for an Application not at offer is refused

Refused before any service call: the narrative is the offer-time
retrospective (ARCHITECTURE.md §4 — "on `.offer`"), so every other status
refuses, naming the reason. The refusal is the store-level backstop behind
the UI gate ([JOURNEY-14]).

## [JOURNEY-6] Generating a narrative with no API key stored is refused

Checked at run start, before any service call; the refusal directs the
user to Settings — the [TAILOR-4] / [DEBRIEF-6] / [PREP-6] stance.
Production never falls back to fixture data; `FixtureIntelligenceService`
stays a test and preview concern.

## [JOURNEY-7] The journey request contains the versioned journey prompt

`Prompts/journey.md` is born in this slice: the canonical, versioned
journey prompt, loaded at runtime — never an inline string. The fixture
service records the request it receives; the recorded prompt equals the
file's content, and the recorded payload carries the Application's
company, role title, applied date, and Stage chain ([JOURNEY-8]).

## [JOURNEY-8] The journey payload lists every Stage in chain order with its debrief content where present

The full chain, walked by `sortIndex`: each Stage contributes its kind,
scheduled date, and outcome; a Stage with a debrief also contributes that
debrief's themes, signals, and question entries. A Stage without a
debrief still appears — the chain is the story's spine, and a stage the
user never debriefed is still a step they climbed.

## [JOURNEY-9] The narrative carries the service's text verbatim

Persisted as returned, never re-derived or reworded — the [TAILOR-7] /
[DEBRIEF-16] / [PREP-14] stance. On-screen arrangement goes to the
visual-verify list; this criterion pins the persisted content.

## [JOURNEY-10] A response failing validation triggers exactly one repair request

Validation is minimal (decisions/0002): the response must parse as a JSON
object whose `narrative` is a non-empty string. On failure, the
[TAILOR-9] loop (Tailor decisions/0004): the repair request carries the
original request content, the invalid response, and a description of the
failure. A valid repair response produces the narrative as normal.
Exactly one — an invalid-then-valid fixture sequence records two
requests, never three.

## [JOURNEY-11] A repair response failing validation fails the run

The second failure ends the run in a failed state naming the reason;
nothing is written, and a narrative already on the Application stays
exactly as it was — replacement happens only on a valid result
([JOURNEY-12]).

## [JOURNEY-12] Generating a narrative for an Application that already has one replaces the existing narrative

One narrative per Application (the to-one link, decisions/0001). On a
valid result the old `JourneyNarrative` is deleted from the store, never
orphaned — the [DEBRIEF-15] / [PREP-17] policy: regenerating is the
correction path, no confirmation step.

## [JOURNEY-13] A journey result wrapped in a markdown code fence produces a narrative

Live models mirror the fenced schema example in the prompt and wrap their
JSON in a ```json fence despite the "only JSON" instruction
([CVIMPORT-18], [TAILOR-18], [DEBRIEF-17], [PREP-18]). The shared
`FencedJSON` helper strips it before validation, so a fenced-but-valid
result becomes a narrative without consuming the single repair request on
a formatting quirk.

## [JOURNEY-14] The generate action appears only on an Application at offer

The UI face of the offer-time gate ([JOURNEY-5] is the store backstop):
on the Application detail, the generate control renders for `.offer` and
for no other status. An already-generated narrative stays visible
whatever the status ([JOURNEY-15]); only the action is gated. Button
chrome is visual-verify.

## [JOURNEY-15] The journey section shows the persisted narrative text

Modest plain text, inline on the Application detail — the Baton #151
ruling: store + plain display, no illustration, no collapse-to-window.
The section renders only when the Application carries a narrative or is
at `.offer` (the empty-at-offer state offers generation, [JOURNEY-14]);
other Applications show no journey section. Section chrome and the
`generatedAt` caption are visual-verify.

## [JOURNEY-16] Removing the narrative requires confirmation before deleting it

Confirming deletes the `JourneyNarrative` from the store with no orphans;
the Application and its Stages survive untouched. Declining changes
nothing. An API call recreates it, hence the confirmation — the
[DEBRIEF-20] / [PREP-22] stance. Dialog chrome is visual-verify.
