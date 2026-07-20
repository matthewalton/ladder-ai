# 0003 — Re-import replaces the existing transcript, after a flagged confirm

Status: accepted (agreed with the human at plan, 2026-07-20)

## Context

`Stage.transcript` is to-one (ARCHITECTURE.md §3) — a Stage has one
conversation. But imports go wrong: a mislabeled paste, the wrong Stage, a
better export. The slice has no segment editing (out of scope), so
re-import is the only correction path, and it must neither silently
clobber a good transcript nor strand the user behind a delete-first dance.

## Decision

Importing onto a Stage that already has a transcript proceeds through the
normal preview, which carries a replacing indicator ([TRANSCRIPT-15]) so
the sheet warns; confirming deletes the old `Transcript` from the store and
attaches the new one ([TRANSCRIPT-14]). The notes overview travels with the
transcript — replaced together, never merged.

## Consequences

- One transcript per Stage stays an invariant; no orphaned `Transcript`
  rows accumulate.
- Replacement is destructive after confirm — there is no undo. Accepted:
  the source text still exists in Granola, so re-replacing is cheap.
- Cancelling from the flagged preview writes nothing ([TRANSCRIPT-13]).
