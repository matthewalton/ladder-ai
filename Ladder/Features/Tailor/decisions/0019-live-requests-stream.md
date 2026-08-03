# 0019 — Live requests stream, and the timeout becomes an idle timeout

Status: accepted (agreed with the user at plan stage, 2026-08-03)

## Context

This slice turned live API access on and owns the live service's request shape
(decisions/0003, [TAILOR-17]), even though `AnthropicIntelligenceService` sits
in `Ladder/Shared/Services/`. ADR 0009 settles the seam every slice sees; this
records what changes on the wire.

The response is currently fetched with `urlSession.data(for:)` and decoded
whole: the first `text` block is found by skipping past the thinking blocks
that adaptive thinking puts before it, and `stop_reason` is read off the same
envelope.

## Decision

The live request sets `"stream": true` and is read with
`URLSession.bytes(for:)`, parsing the Messages API's server-sent events.

- The returned `Data` is the accumulated `text_delta` content — the same JSON
  the caller receives today, assembled from deltas instead of found in a block.
- `stop_reason` arrives on the `message_delta` event rather than on the whole
  response. The truncation guard survives that move unchanged in behaviour:
  `"max_tokens"` throws `LiveServiceError.truncated` **before any text is
  returned to the caller**, so truncated JSON still never reaches validation.
- `timeoutInterval` drops from 300s to 60s. Continuously arriving bytes reset
  it, so the value that was a whole-run ceiling becomes a dead-connection
  detector, and 60s of total silence is a dead connection rather than a slow
  run.
- When the request carries `narrateThinking` (ADR 0009), `thinking_delta`
  events are surfaced to the delta callback. Nothing in this slice reads them
  yet — the waiting screen that does is Baton #234.

## Consequences

- [TAILOR-17] is amended: the request-building seam now also asserts
  `"stream": true`, and the thinking field when the flag is set.
- [CVIMPORT-19] needs a body amendment, and its statement does not change. Its
  body says `stop_reason` is "decoded alongside the content blocks", which
  describes the mechanism this decision replaces; the promise it makes — a
  truncated response fails with its own reason rather than as invalid JSON —
  is unaffected. That body also still cites a "16k cap" that main raised to
  32000; the same amendment corrects it.
- Tests still never reach the network. The request-building seam stays a pure
  function and is asserted as today; the SSE reader is exercised by feeding it
  recorded event bytes directly, never a live connection.
- The repair loop (decisions/0004) is unchanged — it still runs once, and a
  repair request streams like any other.
- Raising `max_tokens` toward the model's 128k ceiling is now safe from a
  timeout standpoint. It is deliberately not part of this change.
