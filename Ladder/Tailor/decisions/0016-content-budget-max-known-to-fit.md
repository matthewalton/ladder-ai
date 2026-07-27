# 0016 — The content budget is the maximum volume known to fit, or nothing

**Status:** accepted (2026-07-27, agreed with the human)

## Context

Ticket #161 left FitMetrics on each Application as "feedstock for future
selection budgets": per export, the content volume, the passes the fit loop
needed, and the page counts. Slice 3 spends that feedstock — the tailor
prompt should aim the selection at a volume that fits two pages first time,
so the condense/trim ladder stays a safety net instead of a routine step.
How is the budget derived, and what happens before any history exists?

## Decision

- **Qualifying records**: every Application's `fitMetrics` where
  `finalPageCount` ≤ 2, `condensePassRun` is false, and `trimPassCount` is
  0. Deterministic density work (compaction steps, underflow stretch) is
  free and does not disqualify; service passes do — they mean the volume as
  selected did not fit.
- **The budget is the per-field maximum across qualifiers** — bullets,
  projects, characters each take their own max. The most volume ever proven
  to fit is the least restrictive true bound.
- **No qualifying history → no budget line at all.** The payload stays
  byte-shaped as today; the model behaves as it did before this slice. No
  invented default.
- **Advisory only.** The budget is an aim-for line in `Prompts/tailor.md`'s
  payload; the fit loop remains the enforcement ([CVEXPORT-26..28]).

## Considered options

- *Median of fitting exports* — lands safely under budget but systematically
  under-fills; the underflow stretch already covers short CVs, so the
  conservatism buys nothing. Rejected.
- *Static default until history exists* — predictable first run, but the
  number is invented and fights the fit loop on dense profiles; an absent
  line that appears once an export proves what fits is honest. Rejected.

## Consequences

- A pure helper over FitMetrics ([TAILOR-56]) — testable without a store or
  a service.
- The budget sharpens itself as exports accumulate; a trimmed export never
  raises it.
- Reading `FitMetrics` from another slice's model is a read-only dependency,
  the same direction the fit loop already crosses; CVExport's spec is
  untouched.
