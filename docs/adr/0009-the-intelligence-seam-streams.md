# 0009 — The intelligence seam streams, additively

**Status:** accepted (agreed with the user at plan stage, 2026-08-03)

## Context

`IntelligenceService.complete(_:) -> Data` is the one door every slice uses to
reach a model: 18 call sites across nine slices, six conforming types — three
shipped (`AnthropicIntelligenceService`, `FixtureIntelligenceService`,
`TourIntelligenceService`) and three test doubles.

The live implementation sends an unstreamed POST. Because no bytes arrive until
generation finishes, `URLRequest.timeoutInterval` is a ceiling on the whole run
rather than an idle timeout, and at its 60s default every live tailor run on an
adaptive-thinking model died there. The stopgap on main raised the ceiling to
300s and `max_tokens` to 32000 — it bought time without changing the shape of
the problem. CVImport decisions/0006 named streaming explicitly as deferred
work; this is that work.

Streaming also produces something the app has never had: intermediate signal
during a run that legitimately takes minutes. The waiting screen that spends it
is separate work (Baton #234), but the seam it consumes is settled here,
because a seam is expensive to change twice.

The whole-loop alternative — widening `complete` itself to carry progress —
was rejected. It is a breaking change to 18 call sites and all six conformers
in service of a fix whose actual job is a timeout.

## Decision

Two additive changes to shared ground. Neither breaks an existing caller.

1. **The protocol gains a streaming method** alongside `complete`, carrying a
   delta callback and returning the same accumulated `Data`. A protocol
   extension supplies a default that ignores the callback and calls `complete`,
   so the five conformers that have nothing to stream inherit working
   behaviour and are not edited. Only `AnthropicIntelligenceService` overrides
   it. The method's name and the delta type's shape are settled at spec time.

2. **`IntelligenceRequest` gains `narrateThinking`, defaulting to false.** When
   true the built request carries `thinking` as adaptive with `display` set to
   summarized; when false the request is unchanged from today. Thinking already
   runs on the pinned model and is billed the same either way — `display`
   controls visibility only — so the flag costs nothing extra. It asks for
   narration on the wire, and is set only where a surface will read it.

The tailor and JD-scan passes set the flag. Every other caller leaves it unset,
and their requests go out byte-identical to today.

## Consequences

- `complete(_:) -> Data` keeps its signature. No call site changes; five of six
  conformers are untouched.
- Baton #234 has a seam to build the live waiting screen on without reopening
  this decision.
- A caller that wants neither streaming nor narration writes nothing new — the
  defaults are the current behaviour.
- The wire mechanics of the live request — SSE parsing, where `stop_reason`
  now arrives, the timeout — are Tailor decisions/0019, on the slice that owns
  the live service.
- This is the first path along which model output reaches the app
  incrementally. The privacy posture is unchanged: the key stays in the
  Keychain, nothing new is logged, and no content leaves the machine that did
  not already.
