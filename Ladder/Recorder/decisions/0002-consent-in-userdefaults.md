# 0002 — First-run consent is a once-ever UserDefaults flag

Status: accepted (agreed with the human at plan, 2026-07-19)

## Context

ROADMAP Phase 3 exit criterion 2 requires first-run consent before the first
capture — Ladder's own gate, on top of the OS microphone permission. The
flag must persist across relaunches, and the options were a `UserDefaults`
key or a small SwiftData settings model in the shared schema.

## Decision

The consent flag is a `UserDefaults` boolean. It is an app-level preference,
not domain data: putting it in the schema would buy nothing and would put a
single boolean under the phase's migration-safety criterion. The gate runs
before the mic access check in the record action — consent is asked once,
sober of any permission dialog, and accepting it is what leads on to the OS
prompt.

Consent screen copy (visual-verify under [RECORDER-5]):

> Before your first capture: Ladder listens to your microphone only while
> you record, shows you levels, and keeps nothing — no audio is stored, and
> nothing leaves this Mac. Transcription, when it arrives, happens on this
> Mac too.

Declining writes nothing — the next record action asks again ([RECORDER-7]).

## Consequences

- Tests inject a scratch `UserDefaults` suite and never touch the standard
  one (AGENTS.md); relaunch is simulated by a second store over the same
  suite ([RECORDER-6]).
- The shared SwiftData schema is untouched by this slice — no migration
  surface, nothing new under the Phase 3 migration-safety exit criterion.
- If consent ever grows structure (per-source consent when system audio
  arrives), that is a new decision, not a widening of this flag.
