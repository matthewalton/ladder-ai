# 0012 — The Match score is a derived coverage percentage

**Status:** accepted (2026-07-27, agreed with the human)

## Context

Root ADR 0005 fixes that the Match score is deterministic — computed in
Swift from tag overlap alone, recomputable live and offline as suggestions
toggle in the coming Match review. It does not fix what the number *is*, or
whether it is stored.

## Decision

The score is **coverage**: matched asks ÷ (matched + vocabulary gaps),
expressed as a whole percentage rounded half-up. A Match with no asks at all
has no score — nil, not zero and not a hollow 100. The score is **derived on
read and never stored**: it is a pure function of the Match's matched and
gap counts, so persisting it could only let it drift from what it summarises.

## Considered options

- *Matched/total pair with no single number* ("12 of 18 asks covered") —
  honest about precision, but the review's live-recompute checkboxes have no
  single figure to move, and two Applications compare awkwardly. The pair
  survives anyway: it is one derivation away, and UI may show both.
- *Matched count alone* — simplest, but incomparable across JDs of
  different sizes. Rejected.
- *Storing the computed score on the Match* — a cache with drift risk and
  no read it could speed up. Rejected.

## Consequences

- Accepting a suggestion in the coming review dissolves a gap and moves the
  numerator, so the score visibly rewards curating the vocabulary — and only
  that ([TAILOR-41] carries the worked examples).
- Any surface with a Match can show its score offline, with no API call and
  no stored field to invalidate.
