# 0005 — JD import via shared on-device text extraction

Status: accepted (2026-07-20, agreed with the human at the plan stage)

## Context

Until this slice grew the JD import, the Tailor export was the only writer of
`Application.jobDescription`; a manually added Application carried an empty
job description with no way to fill it, starving the prep-pack input guard
([PREP-5]) and the debrief payload. The human's ask (Baton ticket 155): drop a
PDF of the JD onto an existing Application and have the app take it from
there.

CVImport already owned exactly the needed machinery — `CVTextExtractor`,
PDFKit for PDF and Office Open XML reading for docx, entirely on-device — but
it lived in `Ladder/CVImport/src/` and threw CVImport's `ImportError`.

## Decision

1. **Plain extraction, no LLM.** The extracted text lands raw as the job
   description — no IntelligenceService cleanup, no prompt, no API key
   requirement. The editor surface ([PIPEBOARD-21]) is the correction path.
2. **PDF and docx both accepted** — the docx branch already exists in the
   extractor, so the second format is free.
3. **The extractor lifts to `Ladder/Shared/Services/`** as the shared
   file→text extractor with a slice-neutral error type; CVImport calls the
   shared one and maps its errors onto `ImportError` (its criteria pin the
   `ImportError` states, not the extractor's location or type names).
   PipelineBoard depending on a CVImport type was the rejected alternative:
   a slice-to-slice dependency that drags `ImportError` across the boundary.
4. **Confirm-then-replace.** Importing onto a non-empty job description
   requires an explicit confirmation; onto an empty one it lands silently
   ([PIPEBOARD-25]).

## Consequences

- Two slices share one extractor; a future format lands in one place.
- CVImport's suite must stay green through the lift — the move is observable
  only in file layout, never in behaviour.
- URL import / scraping stays out: the user supplies the file. An LLM
  cleanup pass, if ever wanted, is a new decision.
