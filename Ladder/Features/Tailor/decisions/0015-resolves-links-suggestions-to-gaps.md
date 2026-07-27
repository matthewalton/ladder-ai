# 0015 — `resolves` links a suggestion to its gap; confirming moves the Match

**Status:** accepted (2026-07-27, agreed with the human)

## Context

The Match review recomputes the score live as suggestions toggle, and root
`CONTEXT.md` promises "accepting a Tag suggestion can dissolve a vocabulary
gap". The score derives from matched and gap counts alone ([TAILOR-41]), so
dissolving needs a mechanical link from a suggestion to the gap it
addresses — and a decision on whether confirmation mutates the persisted
Match or only the pool.

## Decision

- **jd-scan.md bumps to v2: a suggestion may carry `resolves`** — the gap
  entry it dissolves, compared case-insensitively after trimming against the
  scan's own `gaps` array. A `resolves` matching no gap entry fails
  validation into the single repair ([TAILOR-51]). The field is optional: an
  alias for an ask the model already matched semantically resolves nothing
  and moves no score.
- **Confirming an accepted resolving suggestion writes both sides**: the
  pool (mint / alias, [TAILOR-48]) and the persisted Match — the gap string
  leaves `vocabularyGaps`, the resolved Tag joins the matched Tags
  ([TAILOR-49]). The score the user watched in the review survives
  confirmation; `scannedAt` stays, since no scan ran.

This amends the slice-2 stance that gaps change only when a scan runs
([TAILOR-40]'s body): a scan **or a confirmed resolving suggestion** moves
them. Nothing else does.

## Considered options

- *Name-equality linking on v1* (mint name ↔ gap string, case-insensitive) —
  no schema change, but gaps are verbatim-flavoured phrases ("GraphQL API
  design") and mint names are curated ("GraphQL"): the join misses exactly
  when it matters, and a checkbox that sometimes silently moves nothing is
  worse than no checkbox. Rejected.
- *Pool-only confirmation* (Match catches up at the next scan) — simpler
  write path, but the reviewed score regresses the moment the sheet closes,
  and the tailor run that follows immediately would rank against a Match
  that no longer reflects the vocabulary the user just confirmed. Rejected.

## Consequences

- `Prompts/jd-scan.md` v2 + fixture update (a resolving mint, a resolving
  alias, a non-resolving alias).
- The Match gains a second writer; [TAILOR-49] pins its exact semantics and
  [TAILOR-50] pins that cancel writes neither side.
- The scan schema's validation grows one referential check, feeding the
  existing single-repair loop (decisions/0004).
