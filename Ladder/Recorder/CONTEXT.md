# Recorder — language

Slice-local terms. `Application`, `Stage`, and `Profile` are defined in the
root `CONTEXT.md`; none is restated here. "Denied state" follows the same
posture as Calendar Sync's term of that name, here for microphone access.

**Capture**:
One live microphone session, from the record action to stop (or stream
error). Exists only while running — it produces meter levels and elapsed
time, never an artifact.
_Avoid_: recording (implies a saved artifact), take, session recording

**Record action**:
The menu-bar control press that asks for a capture. It runs the gates in
order — consent (decisions/0002), then mic access — and only then starts
the session.
_Avoid_: record button (the control is the UI, the action is the behaviour),
start

**Capture buffer**:
The value-type chunk of PCM samples the seam emits — samples, sample rate,
frame count. No `AVAudioPCMBuffer` crosses the seam (decisions/0001).
_Avoid_: AVAudioPCMBuffer, audio chunk, frame

**Meter level**:
The normalised 0–1 RMS amplitude of the latest capture buffer
([RECORDER-4]), driving the level meter. Derived per buffer, then the buffer
is discarded.
_Avoid_: volume, gain, loudness

**Consent**:
Ladder's own once-ever agreement to capture, shown before the first capture
and persisted in `UserDefaults` (decisions/0002). Distinct from the OS
microphone permission.
_Avoid_: permission (that word is the OS grant), opt-in, onboarding

**Mic access state**:
The OS microphone authorisation as the seam reports it: `notDetermined`,
`granted`, or `denied`. Mirrors Calendar Sync's access-state shape.
_Avoid_: authorization status, permission state

**Denied state**:
The recorder's posture when mic access is refused: an explainer with a
System Settings link, no capture, no error, the rest of the app untouched
([RECORDER-9]).
_Avoid_: permission error, failure

**Recording indicator**:
The menu-bar icon's recording symbol, shown exactly while a capture is live
([RECORDER-11]).
_Avoid_: badge, dot, status light

**Idle**:
The recorder with no capture running — the state stop, decline, and stream
error all return to.
_Avoid_: stopped (stop is the action), inactive
