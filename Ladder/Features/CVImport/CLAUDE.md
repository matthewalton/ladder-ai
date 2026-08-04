# CV Import

On-device text extraction (PDF/docx) → proposal → review → merge into the Profile.

**Edits outside this folder** — a change here usually touches:

- `Ladder/Shared/Services/` — this slice defines the `IntelligenceService` protocol and
  `FixtureIntelligenceService` there, so every later slice inherits both
- `Prompts/import.md` — the prompt
- The machinery that photographs this slice's failed state (ADR 0008) —
  `LadderUITests/ScreenTour.swift` plus its `cv-import-failure` case in `scripts/snapshots.sh`.
  Reaching it is what `-LadderTourImportCV` (the sheet imports the bundled `sample-cv.pdf`
  rather than waiting for a drop XCUITest cannot perform) and `-LadderTourServiceFails` exist
  for; changing `startImport`'s refusals, or the order it checks the key in, reaches both arms

**Traps**

- **Production import is live.** The run reads the API key via the shared `APIKeyStore` and
  calls `AnthropicIntelligenceService`. Tests and previews inject fixtures instead — never
  let a test reach the real path.
- The one Keychain test uses a throwaway UUID-namespaced service name so it cannot collide
  with the real entry.

**Needs eyes**

- The failed state's two arms, at the sheet's width — `scripts/snapshots.sh app cv-import-failure`
  records them as `28-cv-import-failed-needs-key` (the `SettingsLink` arm) and
  `29-cv-import-failed-request` (the retry arm, on a service that refuses). What the frames
  answer is whether the message still reads as one centred block against the two buttons below
  it, and how a long interpolated detail wraps — `message(for:)` puts the service's own words
  mid-sentence, inside parentheses, so the sentence has to survive whatever arrives there.
- Not covered: the drop zone's own hover and drag-target states, which no frame reaches.

Criteria token: `[CVIMPORT-n]`
