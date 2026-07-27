# 0002 — The service contract is one JSON narrative field with the house repair loop

Status: accepted (agreed with the human, 2026-07-21, at the plan stage).

## Context

Every other intelligence slice returns structured JSON validated against
a schema (Tailor, Debrief, PrepPack), with exactly one repair request on
failure (Tailor decisions/0004). A narrative is free prose — there is no
structure to validate and no references to resolve — so a bare-text
response was viable. But a second response convention means a second
parsing path, and the repair loop has proven its worth against fenced
output and truncation quirks.

## Decision

The journey response is JSON: `{"narrative": "..."}`. Validation is
minimal — the object parses and `narrative` is a non-empty string —
and any failure feeds the house loop: exactly one repair request, then
the run fails. `FencedJSON` strips code fences before validation, as
everywhere else. The schema has no other field — nothing that could hold
a score or a probability (ARCHITECTURE.md §1).

## Consequences

- One response convention repo-wide; `FixtureIntelligenceService` serves
  the journey fixture exactly like every other.
- The narrative's shape (headings, paragraphs) is the prompt's business,
  not the validator's — `Prompts/journey.md` owns the voice.
- If Phase 5 wants structured waypoints for the illustrated view, that is
  a schema amendment here, not a new contract.
