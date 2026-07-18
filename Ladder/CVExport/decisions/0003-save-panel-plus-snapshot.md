# 0003 — One render, two destinations: save panel + snapshot

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

The Phase 1 exit criterion is a tailored PDF in the user's hands in under
five minutes — persisting a snapshot the user can't reach doesn't meet it,
and a save-later flow adds a step to the one path that matters. Meanwhile the
Application must keep the exact bytes that were sent.

## Decision

Export runs the macOS save panel (SwiftUI `fileExporter`) so the PDF lands on
disk immediately, and persists the **identical bytes** as `cvSnapshot` — one
render feeds both destinations; there is never a second render, which could
drift. Declining the save panel does not undo the persisted Application: the
export happened; the file is re-obtainable from the snapshot later.

## Consequences

- [CVEXPORT-12] asserts byte-identity at the export seam (the data offered
  for saving vs `cvSnapshot`), not by driving the panel — tests never touch
  the real dialog.
- A share-sheet (`ShareLink`) or re-download-from-Application affordance is a
  later addition, not part of this slice.
