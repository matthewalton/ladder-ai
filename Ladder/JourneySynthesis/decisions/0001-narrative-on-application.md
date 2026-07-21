# 0001 — The narrative is a JourneyNarrative model hung off the Application

Status: accepted (agreed with the human, 2026-07-21, at the plan stage).

## Context

The narrative must persist on the Application (ARCHITECTURE.md §4 —
"persisted on the Application"). Two shapes were viable: a plain
`journeyNarrative: String?` field on `Application` (how pipeline-board
added `notes`), or a separate model linked to-one (how Debrief and
PrepPack hang off Stage). The narrative carries metadata (`generatedAt`)
and belongs to this slice, while the `Application` model is owned by
cv-export — fields inside another slice's model blur ownership.

## Decision

`JourneyNarrative` is a `@Model` owned by this slice: `text` plus
`generatedAt`. `Application` gets a cascade-deleted to-one
`journeyNarrative` relationship, declared in
`Ladder/CVExport/src/Application.swift` with an ownership comment — the
exact pattern of `Stage.debrief` and `Stage.prepPack`.

## Consequences

- Deleting an Application deletes its narrative; nothing dangles
  ([JOURNEY-3]).
- Regeneration deletes the old row and inserts a new one — replacement is
  explicit, never a silent field overwrite ([JOURNEY-12]).
- Lightweight migration adds the optional link; prep-era stores open
  unchanged with `journeyNarrative` nil ([JOURNEY-4]).
- Phase 5's celebration view reads this model as its feedstock; nothing
  else about its shape is constrained here.
