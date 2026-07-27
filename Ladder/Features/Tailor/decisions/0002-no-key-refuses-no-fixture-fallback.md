# 0002 — No API key refuses the run; production never falls back to fixtures

Status: accepted (agreed with the user at plan stage, 2026-07-18)

## Context

This slice turns live LLM calls on. Until now every flow ran on
`FixtureIntelligenceService`'s canned JSON. A user without a stored API key
could either be blocked, or (in debug builds) silently served fixture data.

## Decision

Refuse and point to Settings. The live/fixture boundary the repo has kept
strict stays strict: production behaviour never depends on canned data.

## Consequences

- A tailor run with no stored key refuses at start and points to Settings
  ([TAILOR-4]).
- The live service is selected exactly when a key is present; there is no
  DEBUG fallback path. Fixture data never masquerades as a real tailor result.
- `FixtureIntelligenceService` remains a test and `#Preview` concern only.
