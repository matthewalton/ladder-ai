# 0005 — The Match score is deterministic; the LLM proposes tags, never writes them

**Status:** accepted (2026-07-26)

## Context

Ticket #162: CV content selection should be grounded in an explicit tag
comparison between the JD and the Profile, not pure LLM judgement. That put
two questions on the table — what the JD↔Profile match *is*, and who may
mutate the Tag vocabulary the match depends on. The flow this serves
(CONTEXT.md: JD scan → Match review → tailoring) shows a Match score with
per-suggestion checkboxes whose effect on the score updates live, and lets
accepted tags compound into future matches.

## Decision

- **The Match score is computed in Swift from confirmed tag overlap alone** —
  JD-matched Tags ∩ each point's Tags, resolved case-insensitively through
  primary names and Aliases. LLM-judged relevance (domain, seniority, impact)
  never moves this score; it arrives only later, in per-point stats at
  tailor time.
- **Every mutation of the Tag vocabulary is LLM-proposed and user-confirmed**:
  attaching an existing Tag, minting a new Tag, and recording an Alias are all
  Tag suggestions, gated behind the Match review (or the import review /
  on-demand suggestion flows). Nothing lands silently.
- **The Match review precedes selection.** The tailor selects against a
  confirmed Match, never a raw JD.

## Considered options

- *LLM-informed match score* — richer signal, but the score could not
  recompute live as suggestions are toggled, would not be reproducible, and
  its movements could not be explained tag-by-tag. Rejected: the score's whole
  value is that it only moves when a confirmed vocabulary link changes.
- *Auto-applied tags* (LLM writes, user can undo) — more convenient, but the
  vocabulary is exactly what the deterministic score stands on; silent writes
  would erode the user's trust in — and curation of — the pool the way
  keyword-stuffing games an ATS. Rejected in favour of propose-and-confirm,
  matching the import slice's "nothing lands without confirmation" precedent.

## Consequences

- Toggling a suggestion in the Match review recomputes the score instantly
  and offline — no API call.
- Accepted suggestions persist in the pool, so matches compound across
  Applications; a vocabulary gap dissolved once (e.g. an Alias recorded) never
  reappears.
- Tailoring gains a second review step. The existing tailor review keeps
  evidence gaps and selection rationale; vocabulary is settled before it.
- The tailor prompt may still *see* richer context, but explainability of the
  Match score is a hard constraint on where that context is allowed to act.
