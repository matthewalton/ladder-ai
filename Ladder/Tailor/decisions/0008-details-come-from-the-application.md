# 0008 — Job details come from the Application

Status: accepted (agreed with the human at plan, 2026-07-22; amends the
sheet-input framing of decisions/0001's flow — the transient-run stance
itself is unchanged)

## Context

The tailor sheet collected company, role title and job description by hand.
With import-first creation (PipelineBoard decisions/0008) those details are
extracted from the posting and live on a draft Application before any tailor
runs — retyping them into a sheet would be the exact friction the import
removed, and two sources of truth for the same JD invite drift.

## Decision

The tailor is always presented *for an application*: its `JobDetails` derive
from the Application's stored company, role title and job description, the
run starts on presentation, and the view offers no editing of the details.
The input form is deleted — there is no dual mode. Correcting a bad JD
happens on the application detail (the re-import and editor paths,
[PIPEBOARD-21..28]), then Create CV again.

`TailorStore` is untouched: it always took `JobDetails`; only where they
come from changed. The run remains transient (decisions/0001) — export owns
persistence, now attaching to this same application (CVExport
decisions/0006).

## Consequences

- Tailoring cannot run against an unsaved, ad-hoc JD any more; a JD worth
  tailoring against is an application worth tracking, which the import
  creates in one step.
- The sheet's refusal states simplify: an empty JD is prevented upstream by
  the Create CV gate ([PIPEBOARD-42]) but the store guard stays as the seam
  guarantee ([TAILOR-2]).
- Previews and tests construct an in-memory Application instead of typing
  details.
