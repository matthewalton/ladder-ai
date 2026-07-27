# 0002 — Prep content is forward-looking coaching: no grounding quotes, schema-plus-index validation

Status: accepted (agreed with the human, 2026-07-20, at the plan stage).

## Context

The debrief slice grounds every claim in a verbatim quote of the notes
overview (Debrief decisions/0002), because a debrief asserts what
happened and an LLM asked for evidence it does not have will invent it. A
prep pack makes no claims about what happened: likely questions, talking
points, a company brief, and mock tasks are predictions and
recommendations — there is no source text a quote could prove them
against, and most of the pack (JD-derived, kind-derived) has no quotable
source at all.

## Decision

Prep content carries no grounding quotes. Validation is schema conformance
plus achievement-index range ([PREP-11]) plus the technical-kind gate on
mock tasks ([PREP-13]) — nothing else. The speculation guard moves into
the prompt instead: `Prompts/prep.md` constrains the company brief to the
job description and pasted prep context only, and instructs that outside
knowledge is never presented as fact (ARCHITECTURE.md §1: no scraping).

Any validation failure triggers exactly one repair request, then the run
fails — the Tailor loop (Tailor decisions/0004), reused unchanged via the
[DEBRIEF-13]/[DEBRIEF-14] shape.

## Consequences

- The pack's provenance story is honest: coaching, not evidence. Nothing
  in the UI or export presents prep content as grounded fact.
- The prompt, not the validator, holds the no-scraping line — accepted
  because the input payload physically contains nothing beyond the JD,
  prep context, prior debriefs, and the Profile, so there is nothing else
  to leak.
- If native capture later gives prep packs a quotable source worth citing
  (e.g. quoting a prior debrief verbatim), that returns as an amendment;
  nothing here constrains its shape.
