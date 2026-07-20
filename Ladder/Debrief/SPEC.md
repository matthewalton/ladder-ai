---
key: DEBRIEF
---

# Debrief

The first Phase 4 slice: after a Stage's call, generate an evidence-based
debrief from the Stage's attached notes overview, the Stage's context, and
the Profile — question entries with answer quality, themes, signals, drills,
and missed ammo pointing back at Profile Achievements. Generation is an
explicit user action in the Stage's settings, through the existing
`IntelligenceService` seam; `Prompts/debrief.md` is born here.

Interim grounding (decisions/0002): `segments` is empty under the notes-only
Granola import (TranscriptImport decisions/0006–0007), so every claim quotes
the notes text it is grounded in, validated verbatim against the notes
overview. Segment-level citations return as an amendment when native capture
lands. Missed ammo is a real SwiftData relationship to Achievements,
referenced by payload index in the service protocol (decisions/0001).

No numeric scores, no offer probabilities — evidence and drills only
(ARCHITECTURE.md §1). The debrief schema has no field that could hold one;
answer quality is categorical.

Out of scope: prep packs and journey synthesis (later Phase 4 slices);
segment-level citations (amendment with native capture); any automatic
generation — the API is called only on the user's explicit action; anything
under `Journey/` (phase gate).

## [DEBRIEF-1] A generated debrief is still on the Stage after the app relaunches

The tracer: a Stage with attached notes → generate → validated debrief
persisted on `Stage.debrief` → reopen the container → still there, content
intact. It proves the guards, payload and prompt assembly, the service seam,
validation, persistence, and the flow's state machine end to end. Exercised
with `FixtureIntelligenceService` returning a canned debrief result from
`LadderTests/Fixtures/`.

## [DEBRIEF-2] A fully-populated Debrief round-trips through a store reopen

Every field: `generatedAt`, themes, signals, drills, and each question entry
with its question, answer summary, answer quality, grounding quote, missed
ammo, and order. Field-for-field equality after reopening the container —
the house pattern ([PROFILE-5], [PIPEBOARD-3], [TRANSCRIPT-2]).

## [DEBRIEF-3] Deleting a Stage deletes its debrief with it

Cascade: after the Stage is deleted and the context saved, a fetch finds no
orphaned `Debrief` and no orphaned question entries. The Achievements linked
as missed ammo survive untouched — the relationship never cascades toward
the Profile.

## [DEBRIEF-4] A Phase 3 Application survives the schema migration with its Stages, notes and CV snapshot intact

Migration safety (Phase 4 exit): open a store written by the Phase 3 schema
(no `Debrief` model, no `Stage.debrief` link) under the new schema — every
Application keeps its Stages, attached notes, and `cvSnapshot`
byte-identical, and each Stage's `debrief` is nil. The [PIPEBOARD-2] /
[TRANSCRIPT-4] pattern, on a new `Phase3Store` fixture.

## [DEBRIEF-5] Generating a debrief for a Stage without attached notes is refused

Refused before any service call — no notes record, or a notes overview that
is nil or whitespace-only. The refusal points at attaching Granola notes
([TRANSCRIPT-28]); there is nothing to ground a debrief in
(decisions/0002).

## [DEBRIEF-6] Generating a debrief with no API key stored is refused

Checked at run start, before any service call; the refusal directs the user
to Settings — the [TAILOR-4] stance. Production never falls back to fixture
data; `FixtureIntelligenceService` stays a test and preview concern.

## [DEBRIEF-7] The debrief request contains the versioned debrief prompt

`Prompts/debrief.md` is born in this slice: the canonical, versioned debrief
prompt, loaded at runtime — never an inline string. The fixture service
records the request it receives; the recorded prompt equals the file's
content, and the recorded payload carries the notes overview, the Stage's
kind and prep context, the Application's company, role title, and job
description, and the Profile's achievements listed with their payload
indices (decisions/0001).

## [DEBRIEF-8] The debrief lists each question the service reported with its answer quality

Question entries in the service's order, each with its question, answer
summary, and answer quality — strong, adequate, or weak, a categorical
judgement, never a number (ARCHITECTURE.md §1). On-screen arrangement goes
to the visual-verify list; this criterion pins the persisted content.

## [DEBRIEF-9] Every debrief claim quotes the notes text it is grounded in

A claim — a question entry, a theme, a signal (CONTEXT.md) — carries a
grounding quote: a verbatim excerpt of the notes overview. Drills are
recommendations, not claims, and carry none. The interim grounding shape
(decisions/0002); segment-level citations return with native capture.

## [DEBRIEF-10] A claim whose quote is absent from the notes overview fails validation

The grounding check: each quote must appear in the Stage's notes overview as
an exact substring — no normalisation, no fuzziness (decisions/0002). A
fabricated quote is an ungrounded claim and is handled exactly like a schema
mismatch: it feeds the repair path ([DEBRIEF-13], [DEBRIEF-14]).

## [DEBRIEF-11] A question entry's missed ammo resolves to Achievements on the Profile

The service references achievements by payload index; the store maps each
index back to the Achievement object it listed and links it — a real
relationship, so the link survives later rewording of the canon
(decisions/0001). An entry with no missed ammo is valid: not every answer
left ammo on the table.

## [DEBRIEF-12] A missed-ammo reference matching no listed achievement fails validation

An index outside the payload's achievement list means the service invented
or garbled career history — the [TAILOR-8] stance. Referential failure feeds
the repair path ([DEBRIEF-13], [DEBRIEF-14]).

## [DEBRIEF-13] A response failing validation triggers exactly one repair request

The [TAILOR-9] loop (Tailor decisions/0004): the repair request carries the
original request content, the invalid response, and a description of the
validation failure. A valid repair response produces the debrief as normal.
Exactly one — an invalid-then-valid fixture sequence records two requests,
never three.

## [DEBRIEF-14] A repair response failing validation fails the run

The second failure ends the run in a failed state naming the reason; nothing
is written, and a debrief already on the Stage stays exactly as it was —
replacement happens only on a valid result ([DEBRIEF-15]).

## [DEBRIEF-15] Generating a debrief for a Stage that already has one replaces the existing debrief

One debrief per Stage (the ARCHITECTURE.md §3 to-one link). On a valid
result the old `Debrief` and its question entries are deleted from the
store, never orphaned — the [TRANSCRIPT-29] policy: regenerating is the
correction path, no confirmation step.

## [DEBRIEF-16] The debrief carries the service's themes, signals and drills verbatim

Surfaced as returned, never re-derived or reworded — the [TAILOR-6] /
[TAILOR-7] stance. Themes and signals are grounded remarks (text plus
quote); drills are plain recommendations (decisions/0002).

## [DEBRIEF-17] A debrief result wrapped in a markdown code fence produces a debrief

Live models mirror the fenced schema example in the prompt and wrap their
JSON in a ```json fence despite the "only JSON" instruction ([CVIMPORT-18],
[TAILOR-18]). The shared `FencedJSON` helper strips it before validation, so
a fenced-but-valid result becomes a debrief without consuming the single
repair request on a formatting quirk.
