# 0009 — Composing writes nothing; export is the only commit

Status: accepted (agreed with the human at the plan stage, 2026-07-28)

## Context

Baton #163. Export was one indivisible action: fit loop, render, persist
(snapshot, rationale, fit metrics, the draft→applied flip), save panel, then
the fit report. The user saw the CV for the first time *after* it was on
record, with no way back — the fit report reported on a decision already
taken.

Putting a preview in front of the export forces the question of what the
preview costs. Rendering to show it is cheap; persisting to show it is not,
because `cvSnapshot` is written once and never mutated (ARCHITECTURE.md
invariant; decisions/0001), and every persisted `FitMetrics` record feeds
the content budget every later tailor run reads ([TAILOR-56/57]).

## Decision

Export splits into two steps with the persistence boundary between them:

1. **Compose** — build the document, run the fit loop, render. Returns the
   composed CV and its fit report. Touches no persisted state at all.
2. **Export** — persist snapshot, rationale, fit metrics and the status flip,
   then offer the save panel. Unchanged from today, and still the only
   writer.

The preview shows the composed CV; the fit report moves in front of the
export with it. A composed CV the user abandons leaves nothing behind.

## Consequences

- `cvSnapshot` stays write-once by construction, not by discipline: there is
  exactly one code path that writes it, and it runs at the user's explicit
  Export.
- **A discarded generation records no fit metrics**, so it cannot poison
  `ContentBudget` (Baton #199's open question, answered here rather than
  there). Regenerate lands as a second action beside Edit on the same
  screen, needing no new invariant.
- Composing is not free — the fit loop may still spend condense/trim calls
  (decisions/0008). Composing twice costs twice; that is the price of seeing
  the CV before committing it.
- [CVEXPORT-15/16/17/28] keep their statements: the fit report's *content* is
  unchanged, only the moment it appears.
