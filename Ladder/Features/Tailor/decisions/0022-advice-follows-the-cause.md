# 0022 — The advice a failure gives follows its cause

Status: accepted (agreed with the user at plan stage, 2026-08-04)

## Context

decisions/0021 moved the failure *detail* onto `LiveServiceError` and out of
the four stores that used to write it. It did not move the sentence that
follows the detail, and that half stayed where it was: hardcoded in the views.

Five surfaces render a live failure, and they do not agree:

- `CVImport/src/ImportCVView.swift` — "Check your connection and try again."
- `Tailor/src/Views/TailorView.swift` — the same tail, twice (tailor and scan)
- `PipelineBoard/src/Views/MatchSection.swift` — the same tail again
- `Profile/src/Views/ProfileDetailRail.swift` — no tail at all

Four of the five give one sentence of advice for every cause. When the cause
was an overloaded service the user's connection is fine, so the sentence sends
them to check something that is not broken and says nothing about the thing
that is. The frame `29-cv-import-failed-request` shows it: *"…(the service
reported overloaded_error: Overloaded). Check your connection and try again."*

The fifth gives no advice at all, so the same failure reads differently
depending on which screen the user happens to be on.

## Decision

`LiveServiceError` carries its own advice, in a property switching over `self`
beside `detail`. The switch is exhaustive, so a new case without advice is a
build error rather than a screen that silently loses its tail.

Views render the detail and the advice together and decide neither. The five
surfaces then agree by construction rather than by four authors remembering
the same sentence.

Advice is optional per case. A failure with nothing useful to say gets no tail
rather than a filler one — "try again" on a cause a retry cannot fix is the
same defect this decision exists to remove, one step quieter.

What the advice says is derived from the cause's own retryability, which
decisions/0023 makes knowable: a busy service is worth retrying now, a refused
key is worth a trip to Settings, and a request that was too large will fail
identically however many times it is sent.

## Consequences

- The wording constraint from 0021 still holds for `detail` — it is
  interpolated mid-sentence inside parentheses. The advice is a separate
  sentence and reads as one.
- `ProfileDetailRail` gains an advice tail it never had. That is the point:
  the two screens disagreeing was the second half of the finding.
- A new `LiveServiceError` case is still one edit, and the compiler still
  enforces it — now for two properties instead of one.
- `AnthropicIntelligenceService.failureDetail(for:)` remains the seam to grep
  for when asking which slices show a live failure.
