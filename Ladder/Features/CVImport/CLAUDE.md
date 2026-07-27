# CV Import

On-device text extraction (PDF/docx) → proposal → review → merge into the Profile.

**Edits outside this folder** — a change here usually touches:

- `Ladder/Shared/Services/` — this slice defines the `IntelligenceService` protocol and
  `FixtureIntelligenceService` there, so every later slice inherits both
- `Prompts/import.md` — the prompt

**Traps**

- **Production import is live.** The run reads the API key via the shared `APIKeyStore` and
  calls `AnthropicIntelligenceService`. Tests and previews inject fixtures instead — never
  let a test reach the real path.
- The one Keychain test uses a throwaway UUID-namespaced service name so it cannot collide
  with the real entry.

Criteria token: `[CVIMPORT-n]`
