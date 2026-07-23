# 0008 — The fit loop is automatic, lazy, and recorded

Status: accepted (agreed with the human at the plan stage, 2026-07-23)

## Context

The reference CV's hard rule: never more than two pages, ideally two full
pages. The tall-view slicing render had no notion of fitting — content
either fit or spilled, and a page boundary could cut a text line in half.
Alternatives considered: a user-facing fit dialog (per-export fiddling for
a document the user already reviewed), and hard truncation in the renderer
(silently mangles reviewed content).

## Decision

Export runs an automatic ladder until the block-paginated render
([CVEXPORT-24]) fits two A4 pages:

1. **Density compaction** — template spacing tightens stepwise
   (`CVTheme` metrics).
2. **Condense pass** — the tailor-owned service call shortens wordy
   bullets, selection unchanged ([TAILOR-25]).
3. **Trim pass** — terminal fallback: the service drops the weakest
   selected items, every drop named in the fit report ([TAILOR-26],
   [CVEXPORT-28]).

Passes are lazy — a fitting render sends no request ([CVEXPORT-26/27]).
Underflow stretches spacing up to 1.25× toward a flush second page once
the natural render passes 1.5 pages; at or below the threshold it renders
natural ([CVEXPORT-29]). Every export persists **fit metrics** — volume,
settings, passes, page counts — on the Application ([CVEXPORT-30]).

## Consequences

- Export is no longer service-free: an over-length CV costs up to two
  extra calls (plus the house single repair each). A pass whose repair
  also fails fails the export with the reason (Tailor decisions/0010).
- The user never configures fit; the loop's whole audit trail is the fit
  report plus the metrics.
- Metrics-driven selection budgets are deliberately deferred (Baton #162):
  this slice records, nothing here learns.
- [CVEXPORT-11]'s round-trip grows the metrics record.
