# 0014 — A failed JD scan fails the tailor flow; no fallback path

**Status:** accepted (2026-07-27, agreed with the human)

## Context

Slice 3 wires the JD scan as the tailor flow's automatic first step (root
ADR 0005: selection runs against a confirmed Match, never a raw JD). A scan
can fail — transport, truncation, invalid-after-repair ([TAILOR-32]). What
does the flow do then, given the Application may hold a Match from an
earlier scan?

## Decision

The whole flow fails, with the reason surfaced and a retry that re-runs from
the scan. No tailor request is ever sent after a failed scan — not against
the raw JD, and not against the stale persisted Match either.

## Considered options

- *Fall back to the existing persisted Match* — friendlier on flaky
  networks, but adds a stale-Match path the spec, tests, and UI must own:
  the Match tracks the pool ([TAILOR-36]), so an old Match silently
  misgrounds the very ranking this ticket exists to make explainable.
  Rejected.
- *Degrade to an unmatched run (raw JD)* — contradicts root ADR 0005's "the
  tailor selects against a confirmed Match, never a raw JD"; would need the
  ADR amended to buy one convenience. Rejected.

## Consequences

- One state machine: scan failure and tailor failure surface the same way —
  failed state, reason, retry ([TAILOR-44]).
- A tailor run costs one extra LLM call (the scan) every presentation;
  accepted at slice-2 planning — scans are cheap and refresh the Match.
