# 0005 — The Granola notes overview imports too, stored on the Transcript

Status: accepted (agreed with the human at plan, 2026-07-20)

## Context

Granola produces two artifacts per call: the raw speaker-labeled transcript
and an AI notes overview (summary). The transcript is what parses into
segments; the overview is already-summarized prose with no attribution to
extract. The human wants the overview captured too — it is the artifact
they actually re-read — and `Stage.prepContext` is the wrong home: that
field is pre-call material, and a summary pasted there would not travel
with the transcript on replace.

## Decision

The import flow accepts an optional second paste, stored verbatim as
`notesSummary: String?` on the `Transcript` ([TRANSCRIPT-16]). Nil when not
provided — never an empty string. It is display-and-storage only: no
parsing, no attribution, and replacement swaps it atomically with its
transcript (decisions/0003).

## Consequences

- The summary and the conversation it summarizes can never drift apart —
  one lives on the other.
- `Transcript` gains a field beyond the ARCHITECTURE.md §3 sketch; the
  sketch is a floor, not a ceiling, and native capture will simply leave it
  nil.
- Phase 4's debrief reads the segments, not the overview — Granola's
  analysis never masquerades as Ladder's.
