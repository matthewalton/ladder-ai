# Transcript import — language

Slice-local terms. `Application`, `Stage`, and `Profile` are defined in the
root `CONTEXT.md`; `stage kind` and `stage outcome` in
`Ladder/PipelineBoard/CONTEXT.md`. None is restated here.

**Transcript**:
The persisted record of one interview conversation attached to a Stage —
`recordedAt`, `durationSec`, optional `sourceApp` and notes overview, and
its ordered Segments. One per Stage; imported and natively-captured
transcripts share this one shape (ADR 0002).
_Avoid_: recording, notes (that is the notes overview), conversation log

**Segment**:
One speaker turn inside a Transcript — attribution, text, optional start
and end times. A `Codable` value type stored on the Transcript, not a
`@Model`.
_Avoid_: line, utterance, message, entry (that word belongs to timeline)

**Attribution**:
Which side of the table a Segment belongs to — `.me` (the user) or `.them`
(everyone else). Two values only; no named speakers are stored.
_Avoid_: speaker identity, diarization, role

**Speaker label**:
The name before the colon on a labeled line of imported text — "Me:",
"Jane Doe:". Consumed by the label heuristic, never persisted.
_Avoid_: speaker tag, prefix

**Label heuristic**:
The attribution rule (decisions/0001): a trimmed, case-insensitive label of
"Me" attributes `.me`; any other label attributes `.them`.
_Avoid_: speaker mapping, speaker picking

**Import**:
The whole paste-or-drop → parse → preview → confirm flow that ends with a
Transcript on a Stage.
_Avoid_: upload, sync, capture (that word belongs to the deferred native
slices)

**Preview**:
The parsed-but-unwritten result shown before confirmation — segments,
attribution, timestamps, and the replacing indicator. Confirming attaches;
cancelling writes nothing.
_Avoid_: review (CV import's word), confirmation sheet (calendar-sync's
word), draft

**Replacing indicator**:
The preview's flag that the target Stage already carries a transcript and
confirming will replace it (decisions/0003).
_Avoid_: overwrite warning, conflict flag

**Readout**:
The Stage detail's rendering of an attached Transcript — one row per
Segment in stored order, timestamp labels when the segments carry times.
_Avoid_: transcript view, log, feed, timeline (that word belongs to the
timeline slice)

**Share link**:
A public `notes.granola.ai/t/…` URL — the URL door (decisions/0006).
Fetched over plain HTTPS; carries the shared document, and the transcript
only when sharing included it.
_Avoid_: deep link, integration, sync

**Shared document**:
What a share link's page embeds: title, created date, the notes tree, and
optionally the transcript.
_Avoid_: note (ambiguous with the notes overview), doc

**Notes overview**:
Granola's AI-generated summary of the call, optionally pasted alongside the
transcript and stored verbatim as `notesSummary` on the Transcript
(decisions/0005). Ladder never generates one — its own analysis is the
Phase 4 debrief.
_Avoid_: summary, AI notes, debrief (the Phase 4 word)
