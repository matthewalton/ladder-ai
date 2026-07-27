# 0003 — The model is pinned to the latest Sonnet; no picker

Status: accepted (agreed with the user at plan stage, 2026-07-18)

## Context

The live Anthropic call needs a model. Options were the latest Sonnet fixed,
Opus fixed, or a user-facing picker in Settings.

## Decision

Pin the latest Sonnet model, hard-coded in `AnthropicIntelligenceService`.
The exact model ID is verified against current Anthropic API documentation at
implement time, not recalled from memory.

## Consequences

- Strong structured-output quality at mid-tier cost for selection/rephrasing
  over a bounded profile payload.
- One less setting to explain; Settings holds only the API key in this slice.
- A future model picker is additive — nothing here forecloses it.
- [TAILOR-17] asserts the pinned model at the request-building seam.
