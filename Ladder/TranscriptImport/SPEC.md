---
key: TRANSCRIPT
---

# Transcript import

The Phase 3 slice, and the interim capture path (ADR 0002) — now scoped to
**Granola notes only** (decisions/0007): a public `notes.granola.ai/t/…`
share link, pasted straight into the Stage's settings, fetches the call's
notes overview and attaches it to the Stage. Share pages expose the
summarized notes only to anonymous viewers (verified 2026-07-20,
decisions/0006), so the transcript machinery — paste parsing, speaker
attribution, the readout — was retired with criteria [TRANSCRIPT-1],
[TRANSCRIPT-5]…[TRANSCRIPT-19], [TRANSCRIPT-21], [TRANSCRIPT-23],
[TRANSCRIPT-24] and [TRANSCRIPT-27]; those ids stay retired forever.

The `Transcript` model keeps its ARCHITECTURE.md §3 shape — `segments`
simply stays empty on a notes import — so Phase 4 and the deferred native
capture slices still land on the model they expect. The Stage shows that
notes are attached, never the full text inline; reading them opens a
separate window.

Out of scope: transcript import in any form (retired; returns with native
capture or a Granola surface that exposes transcripts); authenticated
Granola access — no MCP client, no cache reading, no login (ADR 0002);
debrief generation and anything under `Intelligence/` beyond the protocol
stub (Phase 4, gated).

## [TRANSCRIPT-28] Notes attached from a Granola link are still on the Stage after the app relaunches

The headline flow: paste the share link in the Stage's settings, attach,
relaunch — the Stage still carries the notes. The fetch sits behind the
`GranolaShareFetching` seam (decisions/0006); tests use a fixture fetcher,
the app the live one.

## [TRANSCRIPT-2] A fully-populated Transcript round-trips through a store reopen

Every field: `recordedAt`, `durationSec`, `sourceApp`, `notesSummary`, and
`segments` — empty on every notes import, but persisted faithfully when
present (the model outlives this slice's scope). Field-for-field equality
after reopening the container — the house pattern ([PROFILE-5],
[PIPEBOARD-3], [CVEXPORT-11]).

## [TRANSCRIPT-3] Deleting a Stage deletes its transcript with it

Cascade: after the Stage is deleted and the context saved, a fetch finds no
orphaned `Transcript`. Deleting an Application already cascades through its
Stages ([PIPEBOARD-11]), so the chain reaches the notes too.

## [TRANSCRIPT-4] A Phase 2 Application survives the schema migration with its Stages and CV snapshot intact

Migration safety (Phase 3 exit): open a store written by the Phase 2 schema
(no `Transcript` model, no `Stage.transcript` link) under the new schema —
every Application keeps its Stages and its `cvSnapshot` byte-identical, and
each Stage's `transcript` is nil. The [PIPEBOARD-2] pattern.

## [TRANSCRIPT-22] The shared document's notes render as the notes overview text

The payload's notes tree (headings, bullet lists, paragraphs) flattens to
plain text — headings as `## ` lines, bullet items as `- ` lines indented
by nesting — stored verbatim as `notesSummary`, nil never an empty string.

Edge cases:

- Granola appends a "Chat with meeting transcript: <url>" line for its own
  logged-in web app; it is dropped from the flattened notes — dead weight
  on an anonymous import.

## [TRANSCRIPT-20] The imported transcript's recorded date takes the Stage's scheduled date

`recordedAt` is the Stage's `scheduledAt` when set — the call happened at
the scheduled moment, not the import moment. Dates are passed in
explicitly; tests never read the clock (the [PIPEBOARD-16] pattern).

## [TRANSCRIPT-25] A link import's fallback recorded date is the shared document's created date

The Stage's `scheduledAt` still wins ([TRANSCRIPT-20]); when the Stage is
unscheduled, the document's `created_at` — the call's actual moment —
replaces the import moment as the fallback. The import moment is the last
resort.

## [TRANSCRIPT-26] A share-link fetch failure ends the import in a refused state naming the reason

Offline, a 404, or a page whose payload carries no shared document all
refuse with the reason; nothing is written and the pasted URL stays in the
field for retry.

## [TRANSCRIPT-29] Attaching a link onto a Stage that has notes replaces the existing notes

One notes record per Stage (the ARCHITECTURE.md §3 to-one link). The old
`Transcript` is deleted from the store, never orphaned. Granola is the
source of truth, so re-attaching is the correction path — no confirmation
step (decisions/0007 supersedes the 0003/0004 preview-and-warn flow).

## [TRANSCRIPT-30] Removing the notes deletes the stored record

The remove action clears `Stage.transcript` and deletes the `Transcript`
row; a fetch finds nothing. The Stage returns to its empty import state.

## [TRANSCRIPT-31] A URL that is not a Granola share link is refused without a request

Only `notes.granola.ai/t/…` opens the door; anything else is refused
before any network call — the app never fetches arbitrary URLs.
