# 0011 — Coverage updates live; the LLM re-score runs once, on demand

Status: accepted (agreed with the human at the plan stage, 2026-07-28)

## Context

Baton #163 asks the stats to "back up if changes are positive or negative".
The stats on this screen come from two different places, and they cannot
behave the same way:

- **Deterministic** — the Match score (matched ÷ total, [TAILOR-41]) and each
  point's **Overlap** with the Match's matched Tags (Tailor `CONTEXT.md`,
  root ADR 0005). Pure counting and case-insensitive name comparison.
- **LLM-judged** — the four **relevance stats** per selected point
  ([TAILOR-59]), which arrive with the tailor result. A point the user adds
  from the Profile has none, and a bullet the user rewords has stale ones.

Re-scoring on every keystroke would put the network in the middle of
fiddling with a checkbox.

## Decision

- **Coverage recomputes live and offline** on every selection change: how
  many of the confirmed Match's matched Tags the current selection carries,
  and which of them nothing carries. No service request, ever.
- **Relevance is re-scored once, on demand**, after the user has finished
  editing — a single pass over the edited selection. Until it runs, an added
  point shows as unscored rather than as zero.
- The **Match score does not move** with editing. It scores the Profile
  against the job description, not this CV; root ADR 0005 fixes that and the
  preview must not blur it.

## Consequences

- The number that responds to editing is coverage, not the Match score. The
  preview must label them distinctly or it teaches the user something false.
- Mixing scored and unscored points on one screen is a presentation problem
  the preview owns: unscored is a state, never a zero.
- A re-score is a service call and can fail; failing leaves the previous
  stats and the composed CV untouched.
