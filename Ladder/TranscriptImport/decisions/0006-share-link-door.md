# 0006 — The share link is a third door: plain HTTPS, public payload only

Status: accepted (agreed with the human, 2026-07-20)

## Context

The human's real workflow surfaced immediately: Granola produces a public
share link (`notes.granola.ai/t/…`) per call, and pasting one is easier
than copying transcript text out of the app. ADR 0002 ruled out an MCP
client and cache reading — both authenticated, both heavy. A public share
page is neither: the document (and the transcript, when sharing includes
it) is server-embedded in the page HTML, readable with one unauthenticated
GET. [TRANSCRIPT-12] originally rejected URLs outright; that line is
superseded.

## Decision

A lone `notes.granola.ai/t/…` URL in the import opens the URL door
([TRANSCRIPT-21]): fetch the page over HTTPS, parse the embedded payload
(`documentPanel` → title, `created_at`, notes tree; `documentTranscript` →
segments when present), and feed the same preview → confirm flow. The
fetch sits behind the `GranolaShareFetching` protocol with a fixture in
tests. Attribution maps stream identity: `microphone` → `.me`, any other
source → `.them` ([TRANSCRIPT-23]). No other URLs are ever fetched
([TRANSCRIPT-27]).

## Consequences

- ADR 0002's boundary holds in spirit: no MCP, no cache, no login — the
  app reads only what the link already makes public. The paste and file
  doors remain for everything else.
- The share payload is an undocumented page internal (Next.js RSC flight
  chunks), not an API contract; Granola can break it silently. Fetch or
  parse failure refuses with a reason ([TRANSCRIPT-26]) and the paste door
  is the always-working fallback.
- `documentTranscript` is null unless the link was shared with transcript
  included — a notes-only import attaches a zero-segment Transcript
  ([TRANSCRIPT-24]). The transcript-bearing shape is unverified until one
  is seen; the mapping is written defensively and falls back to notes-only
  rather than guessing.
