# 0005 — Live service via the shared Keychain key store

Status: accepted (agreed with the user at plan stage, 2026-07-18)

## Context

The tailor slice introduced the app's live stack: `AnthropicIntelligenceService`
(already in `Ladder/Shared/Services/`), the `APIKeyStore` protocol with
`KeychainAPIKeyStore`, and the Settings key-entry scene — the key store living
in `Ladder/Tailor/src/`. Import going live makes a second slice depend on the
key store; depending on another slice's `src/` is the coupling the folder
convention avoids.

## Decision

`APIKeyStore.swift` and `KeychainAPIKeyStore.swift` move to
`Ladder/Shared/Services/`, beside the live service they feed. `SettingsView`
stays in the tailor slice — import points at Settings, it does not own key
entry. Import adopts the tailor precedents wholesale: no stored key refuses the
run with no fixture fallback in any build config (Tailor decisions/0002), and
the model stays pinned via the shared service (Tailor decisions/0003).

## Consequences

- `ImportStore` takes a key store plus a `makeIntelligence(key)` factory — the
  `TailorStore` shape — defaulting to `KeychainAPIKeyStore` and
  `AnthropicIntelligenceService` ([CVIMPORT-14], [CVIMPORT-15]).
- A mechanical file move touches the tailor slice's folder but not its
  contract: TAILOR criteria name no file locations, and its tests keep passing.
- One Keychain item (`app.ladder.anthropic`) serves both flows; a key entered
  for tailoring turns import live too.
