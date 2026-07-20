---
key: TRANSCRIPT
---

# Transcript import

The Phase 3 slice, and the interim capture path (ADR 0002): interview
transcripts come from Granola and enter by hand — pasted text or a dropped
`.txt`/`.md` file — onto a Stage. The slice owns the `Transcript` model and
its `Segment` value type in the shape ARCHITECTURE.md §3 defines, plus the
`Stage.transcript` to-one link, so imported and natively-captured transcripts
are indistinguishable downstream and nothing Phase 4 builds against them is
throwaway.

Import is paste-parse-preview-confirm: speaker labels in the text drive
me/them attribution (decisions/0001), timestamps parse when present and are
never invented (decisions/0002), and nothing lands on the Stage without a
confirmed preview (decisions/0004) — the CV-import and calendar-sync house
pattern. A Granola notes overview may ride along as a second paste, stored
on the Transcript (decisions/0005).

Out of scope: any Granola integration — no MCP client, no cache reading
(ADR 0002); native capture and its privacy criteria (the deferred recorder /
transcription / system-audio / pre-call slices); debrief generation and
anything under `Intelligence/` beyond the protocol stub (Phase 4, gated);
editing segments after import — a bad parse is fixed by re-importing.

## [TRANSCRIPT-1] A transcript confirmed onto a Stage is still on the Stage after the app relaunches

The tracer: parse a Granola-style paste, confirm the preview onto a Stage
of a persisted Application, reopen the store — the Stage still carries the
transcript with its segments. Proves the models, the `Stage.transcript`
link, the import store, and persistence in one line.

## [TRANSCRIPT-2] A fully-populated Transcript round-trips through a store reopen

Every field: `recordedAt`, `durationSec`, `sourceApp`, `notesSummary`, and
segments carrying speaker, text, and start/end times. Field-for-field
equality after reopening the container — the house pattern ([PROFILE-5],
[PIPEBOARD-3], [CVEXPORT-11]).

## [TRANSCRIPT-3] Deleting a Stage deletes its transcript with it

Cascade: after the Stage is deleted and the context saved, a fetch finds no
orphaned `Transcript`. Deleting an Application already cascades through its
Stages ([PIPEBOARD-11]), so the chain reaches the transcript too.

## [TRANSCRIPT-4] A Phase 2 Application survives the schema migration with its Stages and CV snapshot intact

Migration safety (Phase 3 exit): open a store written by the Phase 2 schema
(no `Transcript` model, no `Stage.transcript` link) under the new schema —
every Application keeps its Stages and its `cvSnapshot` byte-identical, and
each Stage's `transcript` is nil. The [PIPEBOARD-2] pattern.

## [TRANSCRIPT-5] A line labeled Me parses into a segment attributed to me

The label heuristic (decisions/0001): Granola marks the mic side "Me". The
label match is case-insensitive on the trimmed label ("Me:", "me:", "ME:").

## [TRANSCRIPT-6] A line labeled with any other speaker parses into a segment attributed to them

Any label that is not "Me" — a name ("Jane Doe:"), "Them", "Interviewer" —
attributes `.them`. No per-import speaker picking (decisions/0001); the
label text itself is not stored, only the attribution.

## [TRANSCRIPT-7] Unlabeled lines following a speaker label join that speaker's segment

Granola wraps a turn across lines: a labeled line opens a segment, and
subsequent lines without a label append to its text (joined with newlines
collapsed to spaces) until the next labeled line. Blank lines between turns
are dropped, never segments.

## [TRANSCRIPT-8] A timestamp on a speaker line becomes the segment's start time

`MM:SS` or `H:MM:SS`, in parentheses after the label or bracketed at the
line start — "Me (01:23):", "[01:23] Me:" — parses to seconds. A range
("01:23 - 01:41") also sets the end time. A line with no timestamp leaves
both nil (decisions/0002 — nothing is invented). `durationSec` derives from
the last segment's end time, else its start time, else 0.

Edge cases:

- "Me (1:02:03):" → tStart 3723: the third colon group is hours, not a
  malformed minute.

## [TRANSCRIPT-9] Text with no speaker labels is refused

No labeled line means nothing can be attributed: the import ends in a
refused state naming the problem, and no preview opens. Whitespace-only
input refuses the same way.

## [TRANSCRIPT-10] Pasting transcript text produces a preview of the parsed segments

The preview carries every parsed segment with its attribution and any
timestamps, before anything is written (decisions/0004). What the preview
sheet looks like is visual-verify; the criterion claims the preview model
derived from a paste.

## [TRANSCRIPT-11] Dropping a .txt or .md file produces a preview of the file's parsed segments

The file's text enters the same parse as a paste — one pipeline, two doors.
Extension matching is case-insensitive (`.TXT` drops fine).

## [TRANSCRIPT-12] A dropped file that is neither .txt nor .md is rejected

The [CVIMPORT-12] pattern: the drop is refused with the reason, and no
preview opens. PDFs, audio, and Granola URLs are all rejected — text is the
only door (ADR 0002).

## [TRANSCRIPT-13] Cancelling the preview leaves the Stage unchanged

Dismissing without confirming writes nothing: the Stage's transcript —
existing or absent — is exactly as before, and no `Transcript` row persists.

## [TRANSCRIPT-14] Confirming an import onto a Stage with a transcript replaces the existing transcript

One transcript per Stage (the ARCHITECTURE.md §3 to-one link). After
confirmation the old `Transcript` is deleted from the store, not orphaned,
and the Stage carries only the new one (decisions/0003).

## [TRANSCRIPT-15] The preview flags when confirming will replace an existing transcript

The preview model carries a replacing indicator exactly when the target
Stage already has a transcript, so the sheet can warn before the confirm
(decisions/0003). The warning copy is visual-verify.

## [TRANSCRIPT-16] The imported transcript carries the pasted notes overview

The optional second paste — Granola's AI notes (decisions/0005) — lands as
`notesSummary` on the confirmed Transcript, verbatim. Left empty, the field
is nil, never an empty string. Replacing a transcript replaces the notes
overview with it.

## [TRANSCRIPT-17] The readout derives one row per segment in imported order

The Stage detail's timestamped readout: rows follow the segments' stored
order, each carrying its attribution — the derived-model pattern
([PIPEBOARD-13], [CALSYNC-35]). Me/them visual treatment is visual-verify.

## [TRANSCRIPT-18] A readout row carries its segment's timestamp label when the segment has a start time

Rendered `M:SS` (or `H:MM:SS` from the hour up), monospaced digits per
DESIGN.md §2.

## [TRANSCRIPT-19] A transcript whose segments carry no timestamps renders readout rows without time labels

The fallback (decisions/0002): sequence order alone, no time column, never
"0:00" placeholders.

## [TRANSCRIPT-20] The imported transcript's recorded date takes the Stage's scheduled date

`recordedAt` is the Stage's `scheduledAt` when set — the interview happened
at the scheduled moment, not the import moment. An unscheduled Stage falls
back to the import moment, passed in as an explicit date so tests never
depend on the clock (the [PIPEBOARD-16] pattern).
