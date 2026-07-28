# 0013 — Preview edits live for the sitting, not on the Application

Status: accepted (agreed with the human at the plan stage, 2026-07-28)

## Context

The preview's edits could be persisted on the `Application` so a
half-finished CV survives a close. That means a new persisted structure, a
schema migration, and a round-trip criterion — the pattern this repo runs at
every model change ([PIPEBOARD-2], [TRANSCRIPT-4], [DEBRIEF-4], [PREP-4],
[JOURNEY-4]) — plus a staleness question: a stored edit references Profile
points that may have moved on since.

## Decision

Preview edits are held in memory for that sitting. **Closing the preview
with edits pending asks for confirmation first**; confirmed, they are gone.
The record of what was sent remains the CV snapshot, written at export.

Tags applied in the preview are the exception, and not really one: they are
Profile writes that land immediately (decisions/0010), so they survive a
discard. That is correct — the model should learn what it missed whether or
not this particular CV ships.

## Consequences

- No schema change, no migration, no round-trip criterion for this slice.
- A long editing session lost to a mis-click is a real cost; the confirmation
  is the whole mitigation.
- The preview cannot be "come back to later". If that turns out to matter,
  persisting the edited document is a clean follow-on — this decision is the
  cheap half of a reversible pair.
