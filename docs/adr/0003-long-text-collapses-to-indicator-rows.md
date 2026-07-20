# 0003 — Long text collapses to an indicator row

- Status: accepted
- Date: 2026-07-20

## Context

Phase 4 filled the application detail and Stage form with long text: the job
description, application notes, prep context, the debrief, and the prep pack
all rendered fully inline, so a populated form scrolled for screens.
TranscriptImport already solved this for Granola notes: an indicator row shows
the notes are attached, with Open (a separate window) and Remove — the full
text is never inline (`GranolaNotesSection`, `GranolaNotesWindow`).

Settled at the plan stage with the human: scope (all long-text fields), the
open target (separate window), remove confirmation, and the view-only JD
window were agreed; extending editable windows and remove confirmation to the
typed-only fields, and deciding collapse at appearance, were inferred from
those answers and flagged.

## Decision

Every surface that can show a large amount of text adopts the Granola pattern:

- **Collapse.** Content that is set when its form appears is shown as an
  indicator row — the user sees it is set, never the text inline.
  Whitespace-only counts as not set. A field empty at appearance keeps its
  inline editor, and typing never collapses it mid-edit: the collapse decision
  is made at appearance.
- **Open.** A separate window per content kind (`openWindow` carrying the
  model's persistent ID — Granola parity), not a sheet or in-place disclosure.
  The window is **view-only when the content has an alternate input path**
  (the job description: re-import, or remove and retype) and **editable with
  autosave when typing is the only input path** (application notes, prep
  context). Generated content (debrief, prep pack) is view-only by nature.
- **Remove.** Every remove asks for confirmation before clearing or deleting:
  the content is costly to recreate — an API call, or hand-typed text. The one
  exception is Granola notes, which stay one-click: they are trivially
  re-attachable from the share link.
- The indicator row and content-window scaffolding are a shared component in
  `Ladder/Shared/DesignSystem/`; window registration stays in
  `LadderApp.swift`. The Tailor sheet is exempt: a transient review flow whose
  whole point is reading the content right then.

## Consequences

- PIPEBOARD, DEBRIEF, and PREP each gain indicator/open/remove criteria; the
  behaviour stays owned by the slice that owns the surface.
- Inline job-description editing exists only while the JD is empty
  ([PIPEBOARD-21] narrows in body, statement unchanged).
- The debrief and prep pack gain a delete path they never had; regeneration
  keeps its no-confirmation replace ([DEBRIEF-15], [PREP-17]).
- TranscriptImport is untouched; converging `GranolaNotesSection` onto the
  shared component is optional later work.
