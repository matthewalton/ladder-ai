# 0007 — Import is a hard refresh of the Profile

Status: accepted (agreed with the human at the plan stage, 2026-07-21) —
supersedes 0001 (import requires an existing Profile) and 0003 (review is the
dedup)

## Context

Live use showed the add-alongside merge fighting the user's mental model:
importing a CV layered new roles beside the ones already on file, and
re-importing meant hand-rejecting duplicates in review. The user's stance:
"the import should always make the profile fresh." Separately, requiring a
created Profile before importing made first-run a pointless two-step — the CV
carries the identity the create form asks for.

## Decision

Importing a CV replaces the Profile's entire content with the review's
included items, through the Profile slice's replace pathway (Profile
decisions/0008):

- Onto an existing Profile, the run needs an explicit confirmation **before it
  starts** — before extraction and before any paid service call; declining
  aborts. (Settled with the human: confirm up front, not at review confirm.)
- With no Profile on file, the run needs no confirmation and confirming the
  review creates the Profile — import is the second creation path.
- The review stays mandatory; its role shifts from dedup to exclusion.

## Consequences

- 0001 and 0003 are superseded; `ImportError.profileRequired` and the
  duplicate-rejection framing go with them ([CVIMPORT-3], [CVIMPORT-5],
  [CVIMPORT-8] retired).
- Curated content not on the CV is lost on import — by design, and the
  up-front confirmation owns that warning.
- Re-importing the same CV is now the natural "refresh my profile" gesture.
