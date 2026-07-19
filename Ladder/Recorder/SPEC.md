---
key: RECORDER
---

# Recorder

The first Capture slice: a menu-bar recorder that streams the microphone
through the `CaptureService` seam and shows a live meter and elapsed time —
and deliberately keeps nothing. Raw audio crosses the seam as value-type
capture buffers (decisions/0001), the store derives a meter level from each
buffer and discards it, and a capture session never writes a file. The
transcription slice is the future consumer of the buffer stream; this slice
proves the capture path and the privacy posture.

The seam mirrors `CalendarSyncService` (Ladder/CalendarSync/decisions/0001):
a `Sendable` protocol with a mic access state, an `accessState()` /
`requestAccess()` split, and a fixture implementation serving in-code buffers
so every criterion runs headlessly with no microphone permission granted.
`AVAudioEngineCaptureService` is the live implementation, exercised by humans
only. First-run consent (decisions/0002) is Ladder's own once-ever gate,
distinct from the OS permission.

Out of scope: transcription and the `Transcript`/`Segment` models, picking a
Stage at record time (both the transcription slice), system audio, and any
persistence of audio — raw audio never outlives the session (ROADMAP Phase 3
exit criterion 2).

## [RECORDER-1] Starting a capture from the menu bar streams meter levels and elapsed time

The tracer. With consent granted (decisions/0002) and mic access granted, the
record action starts a capture session: the store enters the recording state,
the meter level becomes non-zero as fixture buffers arrive, and elapsed time
advances. The measurable clause is `RecorderStore` fed by
`FixtureCaptureService` buffers of known amplitude; the `MenuBarExtra` popover
rendering the meter and clock is visual-verify.

## [RECORDER-2] Stopping a capture returns the recorder to idle with the meter at zero

The stop action ends the session: state back to idle, meter level zero, the
service's stop recorded through the seam. Elapsed time stops advancing; a new
capture starts its clock from zero.

## [RECORDER-3] A capture session writes no file

The privacy criterion (ROADMAP Phase 3 exit criterion 2), pinned the
[CALSYNC-2] way: run a full fixture session — start, buffers, stop — and the
capture-artifact listing is unchanged: no file created anywhere under the
app's Application Support directory or the temporary directory. The store
derives a level from each buffer and discards the buffer (decisions/0001);
nothing accumulates in memory and nothing reaches disk.

## [RECORDER-4] A capture buffer's meter level equals its RMS amplitude clamped to 0–1

Level derivation is a pure helper over one buffer's samples. Worked examples:
a buffer of constant amplitude 0.5 → level 0.5; a silent buffer → 0; a
full-scale ±1.0 square wave → 1.0; a full-scale sine → ≈0.707. Values above
1.0 (an over-driven float buffer) clamp to 1.0.

## [RECORDER-5] The first record action presents the consent screen instead of starting a capture

With the consent flag unset (a scratch `UserDefaults` suite), the record
action does not touch the seam — the fixture records no capture start — and
the store surfaces the awaiting-consent state. The consent screen copy
(what is captured, that nothing is stored or leaves the Mac) is
visual-verify; decisions/0002 holds the copy.

## [RECORDER-6] Accepted consent persists across app relaunches

Consent is once-ever: accepting writes the flag to `UserDefaults`
(decisions/0002), and a new `RecorderStore` over the same suite — the
relaunch stand-in — starts a capture from the record action with no consent
step.

## [RECORDER-7] Declining consent leaves the recorder idle with no capture started

Declining writes nothing: the flag stays unset, the store returns to idle,
and the fixture records no capture start. The next record action presents
the consent screen again ([RECORDER-5]) — declining is "not now", not
"never ask".

## [RECORDER-8] A record action with undetermined mic access requests access through the seam

Detect-and-guide, first half: with consent granted and the fixture reporting
`notDetermined`, the record action calls `requestAccess()` — the fixture
records the call — and a granted result proceeds straight into the capture
session ([RECORDER-1]); a denied result lands in the [RECORDER-9] state.

## [RECORDER-9] A record action with denied mic access surfaces the denied state and starts no capture

Detect-and-guide, second half (ROADMAP Phase 3 exit criterion 3): the store
surfaces the denied state, throws nothing, and the rest of the app is
untouched. The popover renders a quiet explainer with a System Settings
link — copy and link are visual-verify, the [CALSYNC-17] stance.

## [RECORDER-10] The app bundle carries the microphone usage description

`NSMicrophoneUsageDescription` resolves non-empty from the bundle's Info
dictionary — the [CALSYNC-18] pattern — with the permission-anxiety copy
agreed in decisions/0001: what is heard, that nothing is stored, and that
nothing leaves the Mac.

## [RECORDER-11] The menu bar icon shows the recording symbol while a capture is live

The visible recording indicator (ROADMAP Phase 3 exit criterion 2): the
store exposes the menu-bar symbol name, switching to the recording symbol
exactly while the state is recording and back on stop. The symbol swap in
the running menu bar is visual-verify; the exposed symbol name is the
measurable clause.

## [RECORDER-12] A capture stream error returns the recorder to idle

A live engine can die mid-session (device unplugged, route change). The
fixture ends its stream with an error after delivering buffers: the store
lands in idle with the meter at zero, surfaces the failure quietly, and
crashes nothing — the record action works again immediately.
