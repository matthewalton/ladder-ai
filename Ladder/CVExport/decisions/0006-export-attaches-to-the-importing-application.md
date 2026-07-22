# 0006 — Export attaches to the application the tailor ran for

Status: accepted (agreed with the human at plan, 2026-07-22; supersedes the
fresh-Application-per-export stance of [CVEXPORT-13])

## Context

Export was the moment the Application came into existence: every export
inserted a fresh row with the sheet's typed details. With import-first
creation (PipelineBoard decisions/0008) the Application exists *before* any
tailor runs — created as a draft from the imported posting — and the tailor
starts from it (Tailor decisions/0008). A fresh row per export would strand
the imported draft and duplicate the pursuit.

## Decision

`CVExportStore.export` takes the target application's persistent ID, fetches
it in the store's own context (cross-context mutation would not save), and
attaches: `cvSnapshot` and `cvSelectionRationale` set, company/role
title/job description untouched ([CVEXPORT-8]), a `.draft` flipped to
`.applied` with `appliedAt` stamped only when nil ([CVEXPORT-10]). One
render still serves both destinations ([CVEXPORT-12]).

The `cvSnapshot` write-once invariant is preserved: Create CV is offered
only while the snapshot is nil ([PIPEBOARD-42]). Re-tailoring an exported
application would mean overwriting a sent CV's record — that is a future
decision, not a side effect.

## Consequences

- The application count is unchanged by export ([CVEXPORT-22]); repeat
  pursuits come from repeat imports, each with its own export.
- An abandoned tailor leaves the draft on the board, CV-less, retryable.
- The export seam needs no `JobDetails` any more — the application carries
  them.
