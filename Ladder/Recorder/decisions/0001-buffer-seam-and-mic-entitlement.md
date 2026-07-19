# 0001 — Raw buffers across the capture seam; discard-after-metering; mic entitlement

Status: accepted (agreed with the human at plan, 2026-07-19)

## Context

The slice streams the microphone, which needs a permission grant, an
entitlement, and a usage string — none of which exist headlessly, and ROADMAP
Phase 3 exit criteria demand the suite green with no permissions granted and
raw audio never persisted beyond the session. The repo has the seam shape
twice over: `IntelligenceService` and `CalendarSyncService`, each a protocol
with a fixture serving tests and a live implementation exercised by humans.

Two contracts were on the table for what crosses the seam: derived meter
levels only (the strongest privacy posture — raw audio never leaves the
service), or raw audio buffers (the contract the transcription slice will
consume). The human chose buffers, against the levels-only recommendation:
re-cutting the seam one slice later is the more expensive mistake.

## Decision

All microphone access goes through a `CaptureService` protocol: report the
mic access state (`notDetermined` / `granted` / `denied`), request access,
and stream **capture buffers** — a value type carrying PCM samples, sample
rate, and frame count. No `AVAudioPCMBuffer` crosses the seam, the
`CalendarEvent` precedent. `FixtureCaptureService` (an actor with injectable
state and recorded calls, mirroring `FixtureCalendarSyncService`) serves
in-code buffers to tests and previews; `AVAudioEngineCaptureService` is the
live implementation, exercised by humans only.

The privacy posture rides on top: `RecorderStore` derives a meter level from
each buffer ([RECORDER-4]) and discards the buffer immediately — no
accumulation in memory, no write anywhere ([RECORDER-3]). Raw audio exists
only in flight, inside one session.

The bundle plumbing born here: `com.apple.security.device.audio-input` in
`Ladder/App/Ladder.entitlements`, and
`INFOPLIST_KEY_NSMicrophoneUsageDescription` in `project.yml` with
permission-anxiety copy:

> Ladder listens only while you record an interview, to show levels now and
> transcribe on this Mac later. Nothing is stored, and no audio ever leaves
> this Mac.

Denied access is a state, not an error ([RECORDER-9]), the Calendar Sync
posture exactly.

## Consequences

- Every criterion runs headlessly against the fixture; no test constructs an
  `AVAudioEngine` (AGENTS.md).
- The transcription slice consumes the same buffer stream — the seam is
  already the contract it needs, and adding a consumer must not weaken
  [RECORDER-3]: persistence of *transcripts* is that slice's business, raw
  audio stays unpersisted.
- The usage description is pinned by [RECORDER-10]; the entitlement itself is
  build configuration, verified by the human permission flow.
- Levels are derivable by any consumer ([RECORDER-4] is a pure helper), so
  the seam never needs a levels API.
