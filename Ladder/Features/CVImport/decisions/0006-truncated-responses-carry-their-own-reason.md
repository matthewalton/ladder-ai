# 0006 — A truncated response fails with its own reason, thrown by the shared service

Status: accepted (agreed with the user at plan stage, 2026-07-18)

## Context

`AnthropicIntelligenceService` caps responses at `max_tokens: 16000` and
discarded `stop_reason`. A very long CV — its sections echoed back into
`notImportedSections` — can truncate mid-JSON, surfacing as the generic "the
response was not valid JSON" ([CVIMPORT-17]) with no hint it was a length
problem (Baton #137, speculative from the 2026-07-18 fence failure). The
response envelope is decoded in the shared service, so that is the only place
the signal exists; both import and tailor call it.

## Decision

The service decodes `stop_reason` and throws `LiveServiceError.truncated` when
it is `"max_tokens"`, before returning any text. The import store maps that
throw to a dedicated `ImportError.responseTruncated` — not a
`requestFailed(detail:)` string — because the user action differs: the
`requestFailed` message says "check your connection and try again", and a
retry would truncate again at the same cap. The truncation message names the
length problem instead.

## Consequences

- [CVIMPORT-19] pins the behaviour; [CVIMPORT-18]'s body no longer routes
  truncation to the generic invalid-JSON reason.
- Accepted side-effect in the tailor slice: a truncated tailor response
  previously failed JSON validation and spent its one repair request (Tailor
  decisions/0004) — futile, since the repair reply is subject to the same cap.
  Now `LiveServiceError.truncated` reaches `TailorStore`'s generic catch and
  the run ends `.failed(.requestFailed)` with no repair attempt. No Tailor
  spec change; revisit if a real truncated tailor run warrants its own
  message.
- Raising the 16k cap, chunking, and streaming remain out of scope
  (Ideas-ticket territory, not this amendment).
