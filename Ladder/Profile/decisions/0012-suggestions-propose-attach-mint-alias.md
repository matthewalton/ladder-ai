# 0012 — Suggestions propose attach, mint, and alias from day one

Status: accepted (agreed with the human at plan, 2026-07-26)

## Context

Root ADR 0005: every mutation of the Tag vocabulary is LLM-proposed and
user-confirmed. This slice adds the on-demand door — suggestions requested
from a point's or a Project's detail. The open choice was scope: attach-only
first, or the full proposal surface (attach, mint, alias) at once.

## Decision

All three proposal kinds from day one ([PROFILE-32]). The request carries the
pool vocabulary — primary names and Aliases — so the model can prefer attach
and alias over minting duplicates ([PROFILE-31]). Live LLM access enters the
slice for exactly this flow, via the shared key store and `makeIntelligence`
factory ([PROFILE-37], [PROFILE-38]), with CVImport decisions/0004's
fail-fast stance ([PROFILE-39]). `Prompts/tags.md` is the versioned prompt.

## Considered options

- _Attach-only first pass_ — smaller prompt, smaller review. Rejected: the
  vocabulary gaps that motivate suggestions (ticket #162) are exactly the
  cases where the pool lacks the Tag or the spelling — mint and alias are
  the point.

## Consequences

- The review surface renders three proposal kinds and confirms each
  individually ([PROFILE-33] through [PROFILE-36]).
- Confirm-time resolution guards against stale pool views ([PROFILE-34]).
- The slice's "no live LLM access" scope line is gone; `SPEC.md`'s intro and
  `CLAUDE.md` state the new boundary.
