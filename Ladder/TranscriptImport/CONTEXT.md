# Transcript import — language

Slice-local terms. `Application`, `Stage`, and `Profile` are defined in the
root `CONTEXT.md`; `stage kind` and `stage outcome` in
`Ladder/PipelineBoard/CONTEXT.md`. None is restated here.

**Transcript**:
The persisted record attached to a Stage — `recordedAt`, `durationSec`,
optional `sourceApp`, the notes overview, and `segments` (empty on every
notes import; the field is the ARCHITECTURE.md §3 shape that Phase 4 and
native capture land on). One per Stage.
_Avoid_: recording, conversation log

**Segment**:
One speaker turn — attribution, text, optional times. A `Codable` value
type kept for the model's future consumers; nothing in this slice writes
one (decisions/0007).
_Avoid_: line, utterance, message, entry (that word belongs to timeline)

**Share link**:
A public `notes.granola.ai/t/…` URL — the only import door
(decisions/0006, 0007). Fetched over plain HTTPS; carries the shared
document's notes, never the transcript.
_Avoid_: deep link, integration, sync

**Shared document**:
What a share link's page embeds: title, created date, and the notes tree.
_Avoid_: note (ambiguous with the notes overview), doc

**Notes overview**:
Granola's AI-generated summary of the call, fetched from the share link
and stored verbatim as `notesSummary` on the Transcript. Ladder never
generates one — its own analysis is the Phase 4 debrief.
_Avoid_: summary, AI notes, debrief (the Phase 4 word)

**Attach**:
The one-step import: paste the share link in the Stage's settings, fetch,
write. Re-attaching replaces; remove deletes (decisions/0007).
_Avoid_: import (the retired sheet flow's word), upload, sync, capture
(that word belongs to the deferred native slices)

**Notes window**:
The separate window that shows the full notes overview; the Stage itself
only indicates that notes are attached.
_Avoid_: readout (retired), preview, popover
