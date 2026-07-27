# 0010 — Condense and trim are tailor-owned service passes with tailor-run semantics

Status: accepted (fit-loop ladder agreed with the human at the plan stage,
2026-07-23; failure policy defaulted — single repair then fail the export
with the reason, matching decisions/0004)

## Context

The fit loop (CVExport decisions/0008) needs content shortened when layout
alone cannot land two pages. Rewording is tailoring's monopoly — cv-export
renders and never rewords — so the passes live here, behind the same
`IntelligenceService` seam. The alternative, deterministic truncation in
the renderer, silently mangles bullets the user reviewed.

## Decision

Two versioned prompts, two calls, both invoked only by the fit loop:

- **Condense** (`Prompts/condense.md`, [TAILOR-25]): same selection,
  shorter texts. Validation rejects any selection change; titles are never
  touched (root `CONTEXT.md`).
- **Trim** (`Prompts/trim.md`, [TAILOR-26]): a non-empty strict subset —
  the service judges which items are weakest for this JD. The diff is the
  fit report's trim list ([CVEXPORT-28]).

Validation failures get exactly one repair request (decisions/0004). A
failed repair fails the export run with the reason surfaced — no silent
fallback to cut-off or overflowing output.

## Consequences

- An export may cost up to two extra service calls (plus repairs); an
  export that fits after compaction costs none ([CVEXPORT-26/27]).
- The passes never run user-facing review — the user reviewed the content;
  these passes only shorten or drop, never invent, and every drop is
  reported.
- Tests drive both through `FixtureIntelligenceService` recorded requests.
