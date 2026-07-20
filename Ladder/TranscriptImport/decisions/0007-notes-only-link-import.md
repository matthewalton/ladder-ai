# 0007 — Notes-only: the link is the only door, attached inline from the Stage's settings

Status: accepted (agreed with the human, 2026-07-20). Supersedes 0001
(attribution), 0002 (timestamps), 0003 (replace-on-confirm) and 0004
(preview-before-attach); narrows 0005 and 0006.

## Context

The share-link investigation (decisions/0006) settled it: anonymous share
pages expose the summarized notes only, and the transcript stays behind
the owner's Granola login. That made the transcript half of this slice —
paste parsing, me/them attribution, the readout, the preview sheet —
machinery for a manual workflow the human explicitly does not want.
"I am not interested in manually importing Granola."

## Decision

The slice imports **notes only**, from a pasted `notes.granola.ai/t/…`
link, directly in the Stage's settings — no import sheet, no preview, no
manual paste, no file drop. Attaching fetches and writes in one step;
re-attaching replaces; a remove action deletes. The Stage shows an
attached indicator, never the full notes inline — reading them opens a
separate window.

The `Transcript` model keeps its ARCHITECTURE.md §3 shape with `segments`
empty: renaming or slimming the schema would buy nothing and cost a
migration, and Phase 4 / native capture still land on this model.

Criteria [TRANSCRIPT-1], [TRANSCRIPT-5]…[TRANSCRIPT-19], [TRANSCRIPT-21],
[TRANSCRIPT-23], [TRANSCRIPT-24], [TRANSCRIPT-27] are retired with their
tests; the ids are never reused.

## Consequences

- One paste, one click: the friction the preview flow added is gone, and
  with it the "nothing lands silently" guard — accepted because notes are
  low-stakes, Granola remains the source of truth, and replace/remove make
  any import reversible.
- Transcript import returns as a fresh spec when there is a real source
  for transcripts (native capture, or a Granola surface that exposes
  them) — nothing of the retired flow constrains its shape.
- Phase 4's debrief loses its interim transcript feed: until native
  capture lands, debriefs will have only notes to read. Known trade-off,
  accepted by the human.
