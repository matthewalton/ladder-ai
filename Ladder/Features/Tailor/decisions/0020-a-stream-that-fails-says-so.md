# 0020 — A stream that fails says so, in its own words

Status: accepted (agreed with the user at plan stage, 2026-08-04). The
four-copies consequence below is superseded by decisions/0021.

## Context

Streaming (decisions/0019) moved the reply onto a connection that is already
`200` by the time anything can go wrong. Two failures now arrive through doors
that did not exist unstreamed:

- The Messages API reports a mid-stream failure as an `error` event on the open
  connection — `{"type":"error","error":{"type":"overloaded_error",…}}`.
  Unstreamed this was an HTTP status the `statusCode == 200` guard caught.
- The stream ends without ever reaching a terminal event. A socket-level drop
  already throws out of `URLSession.AsyncBytes`, so what is left is a **graceful
  EOF** — a server or proxy closing cleanly part-way through — which ends the
  sequence with no error at all.

Both currently return the half-written text as a complete reply: `StreamEvent`
decodes every field as optional, so an `error` event decodes with `delta == nil`
and falls through the switch, and nothing observes whether the stream finished.
The caller then reports the model's answer as invalid when the truth is that the
request failed — the exact masquerade [TAILOR-68] and [CVIMPORT-19] exist to
prevent, reached through a door no criterion named.

## Decision

Each failure gets its own `LiveServiceError` case, and the reply is withheld:

- `serviceError(type:message:)` carries the API's own error type and message,
  thrown when an `error` event is decoded.
- `incompleteReply` is thrown when the stream ends having seen neither
  `message_stop` nor a stop reason on `message_delta`.

Reusing `truncated` for either was rejected on the same grounds it was rejected
for the API error: its copy tells the user their CV may be too long to import
whole, which is wrong advice when the cause was an overload. Merging the two new
cases was rejected on the grounds that separates them from each other — an
overload is retryable now, a connection closing mid-reply is not the same
problem, and a single case would either drop that or carry an optional it always
has to test.

Both are transient request failures, so every store maps them through the
`requestFailed(detail:)` it already has, never a new store-level case. That is
the distinction `truncated` earns by being the one failure a retry cannot fix.

## Consequences

- Four stores carry a `requestFailureDetail` and each gains both cases:
  `TailorStore` and `JDScanStore` here, `ImportStore` (CVImport) and
  `TagSuggestionStore` (Profile). A case missing from any of them falls to
  `(error as NSError).localizedDescription`, which for a plain Swift enum renders
  as `The operation couldn't be completed. (… error 3.)` — so this is copy in
  four places or user-visible garbage in three.
- `StreamEvent` gains the event's top-level `type`, which the reader has not
  needed until now, and the `error` object.
- A terminal event is **either** `message_stop` or a stop reason on
  `message_delta`. Recorded streams in the suite already end both ways, and a
  reader demanding one specific event would fail them for the wrong reason.
- `truncated` keeps precedence: a reply cut off at `max_tokens` fails as
  truncated even though its stream is also incomplete, so [TAILOR-68] and
  [CVIMPORT-19] are unchanged.
- The slice's `CLAUDE.md` already promises that "a truncated or malformed event
  sequence gets exercised on purpose". This is the amendment that makes the
  second half of that true.
