# 0002 — The rendered CV is the full history with only selected achievements

Status: accepted (agreed with the human at plan, 2026-07-18)

## Context

Tailoring selects best-fit achievements and reviews their wording, but a CV
that is only a flat list of selected bullets is not a document you can send:
ATS parsers and humans both want the role structure. Three shapes were on the
table: full CV with selected achievements only; full CV with every
achievement (rephrasings swapped in); flat selections list.

## Decision

The rendered CV carries the identity header, **every** Role with title,
company, and month-resolution dates (a role with no selected achievements
still appears — employment continuity), the **selected achievements only**
under their roles in reviewed text, and a skills section naming all of the
Profile's skills. Non-selected achievements are dropped: trimming weak
bullets per application is what tailoring is for. Layout is A4,
single-column, real extractable text via `ImageRenderer` — never a rasterised
page.

## Consequences

- Grouping by Role means achievement identity travels with the reviewed
  outcome to the export seam ([CVEXPORT-4] body); a code-level touch in the
  tailor slice, with no TAILOR criterion change.
- Content criteria ([CVEXPORT-2]–[CVEXPORT-6]) assert against PDFKit text
  extraction, which doubles as the ATS-parseable proof.
- Typst replaces `ImageRenderer` only as a later, separately-decided upgrade
  (ARCHITECTURE.md tech stack).
