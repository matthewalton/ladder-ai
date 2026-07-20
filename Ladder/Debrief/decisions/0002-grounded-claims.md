# 0002 — Notes-grounded claims, validated verbatim, with one repair

Status: accepted (agreed with the human, 2026-07-20; interim shape
ratified in the Phase 4 planning ticket).

## Context

ARCHITECTURE.md §4 wants every debrief claim cited to transcript segments,
but `segments` is empty under the notes-only Granola import (TranscriptImport
decisions/0006–0007) — until native capture lands, debriefs have only the
notes overview to read. Grounding is the product's speculation guard: no
scores, no offer probabilities, evidence only (§1). An LLM asked for
evidence it does not have will invent it; the slice must make fabricated
grounding unrepresentable in the store.

## Decision

Interim, every claim — a question entry, a theme, a signal — carries a
**grounding quote**: a verbatim excerpt of the Stage's notes overview.
Validation checks each quote is an exact substring of the notes overview
(no normalisation, no fuzziness); themes and signals are therefore
**grounded remarks** (text plus quote), a deliberate deviation from
ARCHITECTURE.md §3's bare `[String]`, superseded by the ratified
notes-grounded interim. Drills are recommendations, not claims: no quote.

A validation failure of any kind — fabricated quote, missed-ammo index
matching nothing, schema mismatch — triggers exactly one repair request,
then the run fails: the Tailor loop (Tailor decisions/0004), reused
unchanged.

## Consequences

- A rendered claim can always show the notes text behind it, and a
  fabricated quote cannot reach the store.
- Exact-substring matching is strict on purpose: a "close" quote is a
  paraphrase, and a paraphrase is not evidence. The prompt instructs exact
  copying; the repair path absorbs the occasional slip.
- Segment-level citations return as an amendment when native capture
  lands; that amendment decides how quote fields and segment references
  coexist. Nothing here constrains its shape.
