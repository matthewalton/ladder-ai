# 0023 — Ladder writes every sentence a user reads

Status: accepted (agreed with the user at plan stage, 2026-08-04)

## Context

decisions/0020 gave `serviceError(type:message:)` both halves of what the API
reports on a mid-stream `error` event, and 0021 spent both of them in the
detail: `"the service reported \(type): \(message)"`. Two problems arrived
together, and neither was introduced by the change that made them visible.

`overloaded_error` is the API's own type name. It reaches the screen verbatim,
mid-sentence, inside parentheses, and reads as a leaked internal.

The `message` beside it is a third party's prose, rendered unbounded and
unfiltered. Today's is short and friendly. Nothing guarantees the next one is
short, is a single line, or is written for the person reading it. That was the
open half of the review minor left on the stream reader.

Carrying the type "for the log" is not available: Ladder has no logging. There
is no `os_log`, no `Logger`, and no `print` anywhere under `Ladder/`. The type
either reaches the screen or it goes nowhere.

## Decision

Ladder writes every sentence a user reads. The service's `message` is never
rendered, and neither is its `type`.

The error types are a closed, documented set, so each maps to Ladder's own
wording — a busy service, a rate limit, a refused key, a request that was too
large. A type Ladder does not recognise gets a general sentence saying the
service reported an error, which is true and says nothing a stranger wrote.

This closes the unbounded-text finding by construction rather than by bound:
there is no third-party text on screen to truncate, strip, or wrap.

The mapping is also what makes decisions/0022's advice derivable. Retryability
is a property of the type — a busy service and a rate limit are worth waiting
out, a refused key needs the human, a malformed or oversized request will fail
the same way every time — so the same mapping that produces the sentence
produces the tail that follows it.

## Consequences

- `serviceError` keeps its `type`, which now selects the copy instead of being
  printed. Its `message` is decoded and discarded; the reader still reads it
  because dropping the field would make an unknown payload shape harder to
  recognise, not easier.
- Diagnostic detail for an unrecognised type is genuinely lost, and with no
  log there is nowhere else for it to go. Accepted: a machine token in a human
  sentence is a cost paid by every user on every failure, and the diagnosis it
  buys is paid to nobody, because nothing reads it.
- A type Anthropic adds later renders as the general sentence until Ladder
  maps it. That is a copy improvement, never a failure.
- The tour's injected failure (`TourMode.intelligenceOverride`) sends
  `overloaded_error`, so the photographed frames show the mapped sentence and
  the finding stays visible to the machinery that found it.
