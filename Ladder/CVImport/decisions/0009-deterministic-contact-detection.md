# 0009 — Detected contact values override the proposal

Status: accepted (agreed with the human at the plan stage, 2026-07-21)

## Context

A live import of a real CV returned null contact despite the header text
plainly containing location, phone, and email — the pipeline carried contact
end to end ([CVIMPORT-23]), the model simply didn't return it. Contact fields
are exactly the values deterministic detectors are good at: `NSDataDetector`
finds emails, phone numbers, and URLs with effectively no false negatives,
and a PDF's link annotations can carry URLs that never appear in the text
layer.

## Decision

The import run detects contact values on-device and they win over the model:

- `NSDataDetector` runs over the extracted CV text for email, phone, and URL;
  PDF link annotations are also read for URLs.
- A detected email, phone, or link **overrides** whatever the service
  proposed for that field; a field with no detected value keeps the service's
  proposal.
- Location stays with the model — no deterministic detector is reliable for
  free-form location lines.
- First match wins per field: CV headers lead with the owner's own details,
  and a referee's email appears later in the document if at all.

## Consequences

- Contact import no longer depends on the model obeying the prompt; the
  prompt still asks for contact so location arrives and so the model's view
  fills undetected fields.
- Detection runs between extraction and review, on-device — no extra tokens,
  no network.
- A CV whose links exist only as annotations (icon links) still yields a
  link.
